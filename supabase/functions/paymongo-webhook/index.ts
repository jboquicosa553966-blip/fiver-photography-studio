import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
function equal(a:string,b:string){if(a.length!==b.length)return false;let d=0;for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);return d===0;}
async function sign(secret:string,message:string){const k=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);const s=await crypto.subtle.sign("HMAC",k,new TextEncoder().encode(message));return Array.from(new Uint8Array(s)).map(x=>x.toString(16).padStart(2,"0")).join("");}
Deno.serve(async(req)=>{
 if(req.method!=="POST")return new Response("Method not allowed",{status:405});
 try{
  const raw=await req.text(),header=req.headers.get("Paymongo-Signature")??"";
  const parts:Record<string,string>={};for(const p of header.split(",")){const a=p.trim().split("=");if(a.length===2)parts[a[0]]=a[1];}
  const t=parts.t;if(!t||Math.abs(Date.now()/1000-Number(t))>300)return new Response("Invalid timestamp",{status:401});
  const body=JSON.parse(raw),envelope=body.data??{},attrs=envelope.attributes??{},live=attrs.livemode===true;
  const supplied=live?parts.li:parts.te,secret=Deno.env.get("PAYMONGO_WEBHOOK_SECRET")??"";
  if(!secret||!supplied||!equal(await sign(secret,t+"."+raw),supplied))return new Response("Invalid signature",{status:401});
  const type=attrs.type??envelope.type,eventId=envelope.id??body.id;
  if(type!=="checkout_session.payment.paid")return Response.json({received:true,ignored:true});
  const session=attrs.data??body.data?.data??{},sessionId=session.id,reference=session.attributes?.reference_number;
  if(!sessionId&&!reference)return new Response("Missing checkout session",{status:400});
  const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  if(eventId){
   const {data:prior,error:readErr}=await db.from("webhook_events").select("processed_at").eq("provider_event_id",eventId).maybeSingle();
   if(readErr)throw readErr;
   if(prior?.processed_at)return Response.json({received:true,duplicate:true});
   if(!prior){const {error:insertErr}=await db.from("webhook_events").insert({provider_event_id:eventId,event_type:type,payload:body});if(insertErr&&insertErr.code!=="23505")throw insertErr;}
  }
  let q=db.from("payments").select("id,booking_id,amount").eq("provider","paymongo");
  if(sessionId)q=q.eq("provider_session_id",sessionId);
  const {data:p,error:pe}=await q.maybeSingle();if(pe)throw pe;
  if(p){
   const paid=session.attributes?.payments?.find((x:any)=>x.status==="paid");
   const {error}=await db.from("payments").update({status:"paid",paid_at:new Date().toISOString(),provider_payment_id:paid?.id??null,raw_provider_data:body}).eq("id",p.id);if(error)throw error;
   const {data:b,error:be}=await db.from("bookings").select("id,paid_amount,subtotal,status,reference,user_id").eq("id",p.booking_id).single();if(be)throw be;
   if(["expired","cancelled"].includes(b.status)){
    const {error:re}=await db.from("service_requests").insert({user_id:b.user_id,request_type:"refund",status:"urgent_review",details:{booking_id:b.id,reference:b.reference,reason:"Payment received after booking slot was released. Staff must contact customer and review refund."},amount:p.amount});if(re)throw re;
   }else{
    const totalPaid=Math.min(Number(b.paid_amount)+Number(p.amount),Number(b.subtotal));
    const {error:ue}=await db.from("bookings").update({status:"confirmed",paid_amount:totalPaid,updated_at:new Date().toISOString()}).eq("id",b.id);if(ue)throw ue;
   }
  }else if(reference){
   const {data:b}=await db.from("bookings").select("id,amount_due_now").eq("reference",reference).maybeSingle();
   if(b){const {error}=await db.from("payments").insert({booking_id:b.id,provider:"paymongo",provider_session_id:sessionId,amount:b.amount_due_now,currency:"PHP",status:"paid",paid_at:new Date().toISOString(),raw_provider_data:body});if(error&&error.code!=="23505")throw error;const {data:full}=await db.from("bookings").select("id,status,user_id,reference").eq("id",b.id).single();if(["expired","cancelled"].includes(full.status)){const {error:re}=await db.from("service_requests").insert({user_id:full.user_id,request_type:"refund",status:"urgent_review",details:{booking_id:full.id,reference:full.reference,reason:"Payment received after booking slot was released. Staff must contact customer and review refund."},amount:b.amount_due_now});if(re)throw re;}else{await db.from("bookings").update({status:"confirmed",paid_amount:b.amount_due_now,updated_at:new Date().toISOString()}).eq("id",b.id);}}
  }
  if(eventId)await db.from("webhook_events").update({processed_at:new Date().toISOString()}).eq("provider_event_id",eventId);
  return Response.json({received:true});
 }catch(e){console.error("Webhook error",e);return new Response("Processing failed",{status:500});}
});