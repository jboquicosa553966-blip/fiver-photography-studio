(function(){
 const cfg=window.FIVER_SUPABASE_CONFIG||{};
 const ready=cfg.url&&cfg.anonKey&&!cfg.url.includes("YOUR_PROJECT_REF")&&!cfg.anonKey.includes("YOUR_SUPABASE");
 const styles=document.createElement("style");
 styles.textContent=".backend-panel{position:fixed;inset:0;background:#170f0acc;z-index:99;display:none;align-items:center;justify-content:center;padding:18px}.backend-panel.show{display:flex}.backend-box{background:#fbf7ef;color:#24170f;width:min(560px,100%);max-height:92vh;overflow:auto;padding:26px;border:1px solid #b58a4a;box-shadow:0 20px 80px #0005}.backend-box h2{font:600 2.2rem Georgia;margin:0 0 10px}.backend-box label{display:block;margin:12px 0 5px;font-size:.85rem}.backend-box input,.backend-box select,.backend-box textarea{width:100%;padding:12px;border:1px solid #c9b99f;background:white;font:inherit}.backend-box textarea{min-height:75px}.backend-row{display:grid;grid-template-columns:1fr 1fr;gap:12px}.backend-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}.backend-actions button{padding:12px 16px;background:#49301f;color:#fff;border:0;cursor:pointer;font:inherit}.backend-actions .secondary{background:transparent;color:#49301f;border:1px solid #49301f}.backend-note{padding:12px;background:#efe5d5;margin-top:14px;font-size:.9rem}.backend-status{margin:10px 0;color:#49301f;font-size:.92rem}.account-link{border:1px solid #b58a4a;background:none;color:inherit;padding:8px 12px;cursor:pointer;font:inherit}.booking-list{display:grid;gap:10px}.booking-item{padding:12px;border:1px solid #dfd2bd;background:#fff}.booking-item small{display:block;color:#786b5c}@media(max-width:480px){.backend-row{grid-template-columns:1fr}}";
 document.head.appendChild(styles);
 const panel=document.createElement("div");panel.className="backend-panel";panel.id="booking-panel";
 panel.innerHTML='<div class="backend-box" role="dialog" aria-modal="true" aria-labelledby="backend-title"><button id="backend-close" class="secondary" style="float:right">Close ✕</button><p class="eyebrow">FIVER PHOTOGRAPHY STUDIO</p><h2 id="backend-title">Reserve your session</h2><p>Choose a date and preferred start time. Your slot is held for 15 minutes while you complete the reservation payment.</p><form id="booking-form"><label>Photography package</label><select id="bk-package" required><option value="frame-of-you">Frame of You — ₱599 · 1 hour</option><option value="frames-of-us">Frames of Us — ₱899 · 1 hour</option><option value="frames-together">Frames Together — ₱1,399 · 1.5 hours</option><option value="frames-of-brands">Frames of Brands — ₱1,260 · up to 2 hours</option><option value="frames-of-vision">Frames of Vision — ₱2,200 · up to 2 hours</option></select><div class="backend-row"><div><label>Preferred date</label><input type="date" id="bk-date" required></div><div><label>Start time</label><select id="bk-time" required><option value="">Select time</option></select></div></div><div class="backend-row"><div><label>Number of people</label><input id="bk-party" type="number" min="1" max="20" value="1" required></div><div><label>Payment choice</label><select id="bk-pay"><option value="false">30% reservation fee</option><option value="true">Pay full amount</option></select></div></div><label>Concept / special requests (optional)</label><textarea id="bk-concept" maxlength="1500" placeholder="Tell us about your preferred look or occasion"></textarea><div class="backend-status" id="bk-status" role="status"></div><div class="backend-actions"><button type="submit" id="bk-submit">Continue to secure checkout</button><button type="button" id="bk-account" class="secondary">My bookings</button></div></form><div id="account-view" hidden><h3>Your bookings</h3><div class="booking-list" id="booking-list"></div></div></div>';
 document.body.appendChild(panel);
 const authPanel=document.createElement("div");authPanel.className="backend-panel";authPanel.id="auth-panel";
 authPanel.innerHTML='<div class="backend-box"><button class="secondary" id="auth-close" style="float:right">Close ✕</button><p class="eyebrow">CUSTOMER ACCOUNT</p><h2>Sign in to continue</h2><p>We’ll email you a secure sign-in link. No password needed.</p><form id="auth-form"><label>Email address</label><input id="auth-email" type="email" required placeholder="you@example.com"><div class="backend-status" id="auth-status" role="status"></div><div class="backend-actions"><button type="submit">Email me a sign-in link</button></div></form></div>';
 document.body.appendChild(authPanel);
 const $=s=>document.querySelector(s);
 const status=(msg)=>$("#bk-status").textContent=msg;
 const open=()=>{panel.classList.add("show");$("#bk-date").min=new Date().toLocaleDateString("en-CA");if(!$("#bk-date").value)$("#bk-date").value=$("#bk-date").min;fillTimes();};
 const close=()=>panel.classList.remove("show");
 const durations={"frame-of-you":60,"frames-of-us":60,"frames-together":90,"frames-of-brands":120,"frames-of-vision":120};
 function fillTimes(){const d=durations[$("#bk-package").value]||60;const sel=$("#bk-time");sel.innerHTML='<option value="">Select time</option>';for(let mins=12*60;mins+d<=20*60;mins+=30){const h=Math.floor(mins/60),m=mins%60;const v=String(h).padStart(2,"0")+":"+String(m).padStart(2,"0");const label=(h%12||12)+":"+String(m).padStart(2,"0")+" "+(h<12?"AM":"PM");sel.add(new Option(label,v));}}
 $("#bk-package").addEventListener("change",()=>{const p=$("#bk-package").value;$("#bk-party").min=p==="frames-of-us"?"2":p==="frames-together"?"3":"1";$("#bk-party").value=$("#bk-party").min;$("#bk-party").max=p==="frames-together"?"6":"1";if(p==="frames-of-brands"||p==="frames-of-vision")$("#bk-party").removeAttribute("max");fillTimes();});
 $("#backend-close").onclick=close;
 $("#auth-close").onclick=()=>authPanel.classList.remove("show");
 document.querySelectorAll(".book-package").forEach(btn=>btn.addEventListener("click",()=>{const map={"Frame of You":"frame-of-you","Frames of Us":"frames-of-us","Frames Together":"frames-together","Frames of Brands":"frames-of-brands","Frames of Vision":"frames-of-vision"};$("#bk-package").value=map[btn.dataset.package]||"frame-of-you";fillTimes();open();}));
 const addAccount=()=>{const nav=document.querySelector("#nav nav");if(nav&&!$("#account-nav")){const b=document.createElement("button");b.id="account-nav";b.className="account-link";b.textContent="My bookings";b.onclick=()=>{open();loadBookings();};nav.appendChild(b);}};
 addAccount();
 let sb=null;
 if(window.supabase&&ready){sb=window.supabase.createClient(cfg.url,cfg.anonKey);sb.auth.onAuthStateChange((event,session)=>{if(session&&session.user){const pending=sessionStorage.getItem("fiver-pending-booking");if(pending){sessionStorage.removeItem("fiver-pending-booking");try{const v=JSON.parse(pending);Object.entries(v).forEach(([k,val])=>{const el=document.getElementById(k);if(el)el.value=val;});open();$("#booking-form").requestSubmit();}catch(e){console.error(e);}}}});}
 function showAuth(){authPanel.classList.add("show");}
 $("#auth-form").addEventListener("submit",async e=>{e.preventDefault();if(!sb){$("#auth-status").textContent="Backend is not configured yet. Please contact the studio.";return;}$("#auth-status").textContent="Sending secure sign-in link…";const {error}=await sb.auth.signInWithOtp({email:$("#auth-email").value,options:{emailRedirectTo:location.origin+location.pathname}});$("#auth-status").textContent=error?error.message:"Check your email and open the sign-in link on this device. Then return to booking.";});
 $("#booking-form").addEventListener("submit",async e=>{
  e.preventDefault();if(!ready||!sb){status("Online booking is not activated yet. The studio backend still needs its Supabase project credentials.");return;}
  const {data:{session}}=await sb.auth.getSession();
  const values={"bk-package":$("#bk-package").value,"bk-date":$("#bk-date").value,"bk-time":$("#bk-time").value,"bk-party":$("#bk-party").value,"bk-pay":$("#bk-pay").value,"bk-concept":$("#bk-concept").value};
  if(!session){sessionStorage.setItem("fiver-pending-booking",JSON.stringify(values));showAuth();return;}
  const start=new Date(values["bk-date"]+"T"+values["bk-time"]+":00+08:00");
  if(start<=new Date()){status("Choose a future date and time.");return;}
  $("#bk-submit").disabled=true;status("Checking availability and securing your slot…");
  try{
   const {data:booking,error}=await sb.rpc("create_booking_hold",{p_package_slug:values["bk-package"],p_starts_at:start.toISOString(),p_party_size:Number(values["bk-party"]),p_concept:values["bk-concept"],p_addons:[],p_pay_full:values["bk-pay"]==="true"});
   if(error)throw error;
   status("Slot held. Creating secure payment checkout…");
   const {data:pay,error:payErr}=await sb.functions.invoke("create-checkout",{body:{bookingId:booking.id}});
   if(payErr||!pay?.checkoutUrl)throw new Error(pay?.error||payErr?.message||"Unable to start checkout");
   location.href=pay.checkoutUrl;
  }catch(err){console.error(err);status(err.message||"Booking failed. Please try another time.");}
  finally{$("#bk-submit").disabled=false;}
 });
 async function loadBookings(){
  $("#account-view").hidden=false;
  if(!sb){$("#booking-list").textContent="Backend not configured.";return;}
  const {data:{session}}=await sb.auth.getSession();if(!session){showAuth();return;}
  const {data,error}=await sb.functions.invoke("my-bookings");
  if(error){$("#booking-list").textContent="Could not load bookings.";return;}
  $("#booking-list").innerHTML=(data.bookings||[]).map(b=>'<article class="booking-item"><b>'+b.reference+'</b><small>'+b.package_slug.replaceAll("-"," ")+' · '+new Date(b.starts_at).toLocaleString()+'</small><small>Status: '+b.status.replaceAll("_"," ")+' · Paid: ₱'+Number(b.paid_amount).toLocaleString("en-PH")+'</small></article>').join("")||"No bookings yet.";
 }
 $("#bk-account").onclick=loadBookings;
 const params=new URLSearchParams(location.search);
 if(params.get("payment")==="return"){open();status("Thank you. We are verifying your payment securely. Your booking status will update after PayMongo confirms it.");}
 if(params.get("payment")==="cancel"){open();status("Checkout was cancelled. Your temporary booking hold may remain until its 15-minute expiry.");}
 window.FiverBackend={openBooking:open,loadBookings,configured:!!sb};
 if(!ready){console.warn("Fiver Supabase config missing. Copy js/supabase-config.example.js to js/supabase-config.js and configure it.");}
})();