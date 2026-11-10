import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":Deno.env.get("SITE_ORIGIN")??"*","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const reply=(x:unknown,s=200)=>new Response(JSON.stringify(x),{status:s,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return reply({error:"Method not allowed"},405);
 try{
  const url=Deno.env.get("SUPABASE_URL")!,anon=Deno.env.get("SUPABASE_ANON_KEY")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,payKey=Deno.env.get("PAYMONGO_SECRET_KEY")!;
  if(!payKey)return reply({error:"Payments are not configured yet."},503);
  const token=(req.headers.get("Authorization")??"").replace(/^Bearer\s+/i,"");
  if(!token)return reply({error:"Sign in to continue."},401);
  const auth=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}}});
  const {data:{user},error:authErr}=await auth.auth.getUser(token);
  if(authErr||!user)return reply({error:"Please sign in again."},401);
  const {bookingId}=await req.json();
  if(typeof bookingId!=="string")return reply({error:"Booking reference required."},400);
  const db=createClient(url,service);
  const {data:b,error}=await db.from("bookings").select("id,reference,user_id,package_slug,subtotal,reservation_fee,amount_due_now,paid_amount,status,payment_due_at").eq("id",bookingId).eq("user_id",user.id).single();
  if(error||!b)return reply({error:"Booking not found."},404);
  if(!["pending_payment","confirmed"].includes(b.status))return reply({error:"This booking cannot be paid."},409);
  if(b.status==="pending_payment"&&b.payment_due_at&&new Date(b.payment_due_at)<new Date())return reply({error:"Booking hold expired. Please choose another time."},409);
  const {data:old}=await db.from("payments").select("checkout_url,provider_session_id").eq("booking_id",b.id).eq("status","pending").not("checkout_url","is",null).order("created_at",{ascending:false}).limit(1).maybeSingle();
  if(old?.checkout_url)return reply({checkoutUrl:old.checkout_url,sessionId:old.provider_session_id});
  const {data:pkg}=await db.from("packages").select("name").eq("slug",b.package_slug).single();
  const due=b.status==="confirmed"?Math.max(0,b.subtotal-b.paid_amount):b.amount_due_now;
  const amount=due*100;
  if(amount<=0)return reply({error:"No payment is due."},409);
  const site=Deno.env.get("SITE_URL")??"https://jboquicosa553966-blip.github.io/fiver-photography-studio";
  const payload={data:{attributes:{line_items:[{name:"Fiver Studio - "+(pkg?.name??"Photoshoot")+" ("+b.reference+")",amount,currency:"PHP",quantity:1}],payment_method_types:["card","gcash","qrph"],success_url:site+"/?payment=return&booking="+b.reference,cancel_url:site+"/?payment=cancel&booking="+b.reference,reference_number:b.reference,description:"Fiver Photography Studio booking "+b.reference,send_email_receipt:true,metadata:{booking_id:b.id,customer_id:user.id}}}};
  const response=await fetch("https://api.paymongo.com/v2/checkout_sessions",{method:"POST",headers:{"Authorization":"Basic "+btoa(payKey+":"),"Content-Type":"application/json"},body:JSON.stringify(payload)});
  const data=await response.json();
  if(!response.ok){console.error("PayMongo error",data);return reply({error:"Could not start checkout. Please try again."},502);}
  const session=data.data;
  const {error:saveErr}=await db.from("payments").insert({booking_id:b.id,provider:"paymongo",provider_session_id:session.id,amount:due,currency:"PHP",status:"pending",checkout_url:session.attributes.checkout_url,raw_provider_data:{livemode:session.attributes.livemode}});
  if(saveErr){console.error(saveErr);return reply({error:"Checkout created but could not be linked. Contact the studio before retrying."},500);}
  return reply({checkoutUrl:session.attributes.checkout_url,sessionId:session.id});
 }catch(e){console.error(e);return reply({error:"Unexpected checkout error."},500);}
});