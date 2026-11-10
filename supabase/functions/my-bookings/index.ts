import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":Deno.env.get("SITE_ORIGIN")??"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, GET, OPTIONS"};
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="GET"&&req.method!=="POST")return Response.json({error:"Method not allowed"},{status:405,headers:cors});
 const token=(req.headers.get("Authorization")??"").replace(/^Bearer\s+/i,"");
 if(!token)return Response.json({error:"Sign in required"},{status:401,headers:cors});
 const db=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:"Bearer "+token}}});
 const {data:{user},error:authErr}=await db.auth.getUser(token);
 if(authErr||!user)return Response.json({error:"Invalid session"},{status:401,headers:cors});
 const {data,error}=await db.from("bookings").select("id,reference,package_slug,starts_at,ends_at,subtotal,reservation_fee,amount_due_now,paid_amount,status,created_at,payments(status,amount,paid_at),galleries(id,status,expires_at)").eq("user_id",user.id).order("starts_at",{ascending:false});
 if(error)return Response.json({error:"Unable to load bookings"},{status:500,headers:cors});
 return Response.json({bookings:data},{headers:{...cors,"Content-Type":"application/json"}});
});