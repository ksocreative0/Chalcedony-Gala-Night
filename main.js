(() => {
  const $ = (s) => document.querySelector(s);
  const client = window.galaSupabase;
  const toast = (message) => { const el=$("#toast"); el.textContent=message; el.classList.add("show"); setTimeout(()=>el.classList.remove("show"),3500); };
  const escapeHTML = (s="") => String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const menu=$("#menuToggle"), nav=$("#navMenu");
  menu.addEventListener("click",()=>{const open=nav.classList.toggle("open");menu.setAttribute("aria-expanded",String(open));});
  nav.querySelectorAll("a").forEach(a=>a.addEventListener("click",()=>{nav.classList.remove("open");menu.setAttribute("aria-expanded","false");}));
  if(!client){$("#rsvpNote").textContent="Website setup is pending. Please check back shortly.";return;}
  async function loadSettings(){
    const {data}=await client.from("event_settings").select("*").eq("id",1).maybeSingle(); if(!data)return;
    $("#eventDescription").textContent=data.event_description||$("#eventDescription").textContent;
    $("#headName").textContent=data.head_name||"Head of School";$("#headRole").textContent=data.head_role||"Head of School";$("#headMessage").textContent=data.head_message||"";
    if(data.head_image_url)$("#headPhoto").style.backgroundImage=`linear-gradient(#24160f22,#24160f55),url("${data.head_image_url}")`;
    $("#venueAddress").textContent=[data.venue_name,data.venue_address].filter(Boolean).join(" · ")||"Patron Hotel · Address to be announced";
    if(data.venue_map_url)$("#directionsLink").href=data.venue_map_url;
    const closed=data.rsvp_open===false||(data.rsvp_closes_at&&new Date(data.rsvp_closes_at)<=new Date());
    if(closed){$("#rsvpForm").innerHTML='<p class="closed-message">RSVP registration is now closed. Thank you for your interest.</p>';}
  }
  async function loadProgramme(){
    const {data}=await client.from("event_programme").select("*").eq("is_active",true).order("sort_order").order("start_time");
    if(!data?.length)return;$("#programmeList").innerHTML=data.map(p=>`<article class="timeline-item"><time>${p.start_time?escapeHTML(p.start_time.slice(0,5)):""}</time><div><h3>${escapeHTML(p.activity)}</h3><p>${escapeHTML(p.description||"")}</p></div></article>`).join("");
  }
  async function loadGallery(){
    const {data:deps}=await client.from("departments").select("*").eq("is_active",true).order("sort_order");if(!deps?.length)return;
    const {data:staff}=await client.from("staff").select("*,departments(name)").eq("is_active",true).order("sort_order");
    $("#galleryContainer").innerHTML=deps.map(d=>{const people=(staff||[]).filter(s=>s.department_id===d.id);if(!people.length)return "";return `<section class="department-block"><div class="department-heading"><h3>${escapeHTML(d.name)}</h3><div class="slider-controls"><button aria-label="Previous" data-slide="-1">←</button><button aria-label="Next" data-slide="1">→</button></div></div><div class="staff-slider">${people.map(p=>`<article class="staff-card"><div class="staff-image" style="${p.image_url?`background-image:url('${escapeHTML(p.image_url)}')`:""}"></div><h4>${escapeHTML(p.full_name)}</h4><p>${escapeHTML(p.designation)}</p></article>`).join("")}</div><div class="slide-dots">${people.map((_,i)=>`<span class="${i===0?"active":""}"></span>`).join("")}</div></section>`}).join("");
    $("#galleryContainer").querySelectorAll(".department-block").forEach(block=>{const slider=block.querySelector(".staff-slider");block.querySelectorAll("[data-slide]").forEach(btn=>btn.addEventListener("click",()=>slider.scrollBy({left:Number(btn.dataset.slide)*260,behavior:"smooth"})));slider.addEventListener("scroll",()=>{const dots=block.querySelectorAll(".slide-dots span");const idx=Math.round(slider.scrollLeft/260);dots.forEach((d,i)=>d.classList.toggle("active",i===idx));});});
  }
  async function loadAwards(){
    const {data:cats}=await client.from("award_categories").select("*").eq("is_active",true).order("sort_order");
    window.galaAwardCategories=cats||[];
    renderSponsorshipEntries();
    const {data:nominees}=await client.from("award_nominees").select("id,category_id,staff(full_name,designation,image_url)").eq("is_active",true);
    const {data:settings}=await client.from("event_settings").select("voting_open,results_published").eq("id",1).single();
    if(!cats?.length){$("#awardsContainer").innerHTML='<p class="muted">Award categories will be announced soon.</p>';return;}
    const locked=!settings?.voting_open;
    $("#awardsContainer").innerHTML=cats.map(c=>{const ns=(nominees||[]).filter(n=>n.category_id===c.id);return `<article class="award-card" data-category="${c.id}"><span class="section-kicker">AWARD CATEGORY</span><h3>${escapeHTML(c.title)}</h3><p>${escapeHTML(c.description||"Choose your nominee.")}</p><div class="nominee-options">${ns.map(n=>`<label class="nominee-option"><input type="radio" name="cat-${c.id}" value="${n.id}" ${locked?"disabled":""}><span>${escapeHTML(n.staff?.full_name||"Staff member")} <small>${escapeHTML(n.staff?.designation||"")}</small></span></label>`).join("")}</div>${locked?"<p class='form-note'>Voting is currently closed.</p>":`<button class="button button-gold vote-button" data-cat="${c.id}">SUBMIT VOTE</button>`}</article>`}).join("");
    $("#awardsContainer").querySelectorAll(".vote-button").forEach(btn=>btn.addEventListener("click",()=>submitVote(btn.dataset.cat)));
    if(settings?.results_published)loadPublishedResults();
  }
  function getVoterKey(){let key=localStorage.getItem("chalcedony_gala_voter");if(!key){key=crypto.randomUUID();localStorage.setItem("chalcedony_gala_voter",key);}return key;}
  async function submitVote(categoryId){
    const chosen=document.querySelector(`input[name="cat-${categoryId}"]:checked`);if(!chosen){$("#voteNote").textContent="Please select a nominee before submitting.";return;}
    const {error}=await client.from("votes").insert({category_id:categoryId,nominee_id:chosen.value,voter_key:getVoterKey()});
    $("#voteNote").textContent=error?(error.code==="23505"?"A vote has already been recorded from this browser for this category.":"Your vote could not be submitted. Please try again."):"Thank you. Your vote has been recorded.";
    if(!error)document.querySelectorAll(`[data-category="${categoryId}"] input`).forEach(i=>i.disabled=true);
  }
  async function loadPublishedResults(){
    const {data}=await client.from("published_award_results").select("*").order("category");
    if(!data?.length)return;$("#publishedResults").hidden=false;
    const groups={};data.forEach(r=>(groups[r.category]??=[]).push(r));
    $("#resultsContainer").innerHTML=Object.entries(groups).map(([cat,rows])=>`<div class="result-category"><h4>${escapeHTML(cat)}</h4>${rows.sort((a,b)=>b.total_votes-a.total_votes).map(r=>`<p>${escapeHTML(r.nominee_name)} <strong>${r.total_votes} votes</strong></p>`).join("")}</div>`).join("");
  }
  const sponsorToggle=$("#sponsorToggle"), sponsorFields=$("#sponsorFields"), sponsorshipEntries=$("#sponsorshipEntries");
  let sponsorshipEntryCount=0;
  function renderSponsorshipEntries(){
    if(!sponsorshipEntries)return;
    const cats=window.galaAwardCategories||[];
    sponsorshipEntries.querySelectorAll("select").forEach(select=>{
      const current=select.value;
      select.innerHTML='<option value="">Choose an award category</option>'+cats.map(c=>`<option value="${c.id}">${escapeHTML(c.title)}</option>`).join("");
      select.value=current;
    });
  }
  function addSponsorshipEntry(){
    if(!sponsorshipEntries)return;
    const id=++sponsorshipEntryCount, cats=window.galaAwardCategories||[];
    const wrap=document.createElement("div");wrap.className="sponsorship-entry";wrap.dataset.entry=id;
    wrap.innerHTML=`<div class="sponsorship-entry-heading"><strong>Category sponsorship ${id}</strong>${id>1?'<button type="button" class="text-button" data-remove-sponsorship>Remove</button>':""}</div>
      <label>Award category<select name="sponsor_category_${id}" required><option value="">Choose an award category</option>${cats.map(c=>`<option value="${c.id}">${escapeHTML(c.title)}</option>`).join("")}</select></label>
      <label>Item you would like to sponsor<input name="sponsor_item_${id}" maxlength="200" required placeholder="e.g. Trophy, gift item, cash support"></label>
      <label>Date you can provide the item<input name="sponsor_date_${id}" type="date" max="2026-12-18" min="2026-11-11" required></label>`;
    sponsorshipEntries.appendChild(wrap);
  }
  if(sponsorToggle)sponsorToggle.addEventListener("change",()=>{
    sponsorFields.hidden=!sponsorToggle.checked;
    if(sponsorToggle.checked&&!sponsorshipEntries.children.length)addSponsorshipEntry();
    sponsorshipEntries.querySelectorAll("input,select").forEach(el=>el.required=sponsorToggle.checked);
  });
  $("#addSponsorshipBtn")?.addEventListener("click",addSponsorshipEntry);
  sponsorshipEntries?.addEventListener("click",e=>{
    const b=e.target.closest("[data-remove-sponsorship]");
    if(b){b.closest(".sponsorship-entry").remove();}
  });
  const countdown=$("#countdown");
  if(countdown){const eventAt=new Date(countdown.dataset.event).getTime();const tick=()=>{let diff=Math.max(0,eventAt-Date.now());const vals={countDays:Math.floor(diff/86400000),countHours:Math.floor(diff%86400000/3600000),countMinutes:Math.floor(diff%3600000/60000),countSeconds:Math.floor(diff%60000/1000)};Object.entries(vals).forEach(([id,v])=>{const el=$("#"+id);if(el)el.textContent=String(v).padStart(2,"0");});};tick();setInterval(tick,1000);}
  $("#rsvpForm").addEventListener("submit",async e=>{
    e.preventDefault();const form=e.currentTarget;const raw=Object.fromEntries(new FormData(form));
    const entries=[...(sponsorshipEntries?.querySelectorAll(".sponsorship-entry")||[])].map(el=>({
      category_id:el.querySelector('select').value,
      sponsored_item:el.querySelector('input[type="text"],input:not([type])').value.trim(),
      delivery_date:el.querySelector('input[type="date"]').value
    }));
    const sponsoring=!!raw.is_sponsoring;
    if(sponsoring&&(!entries.length||entries.some(x=>!x.category_id||!x.sponsored_item||!x.delivery_date))){
      $("#rsvpNote").textContent="Please complete every sponsorship category, item and delivery date.";return;
    }
    if(sponsoring&&new Set(entries.map(x=>x.category_id)).size!==entries.length){
      $("#rsvpNote").textContent="Please choose a different award category for each sponsorship.";return;
    }
    if(sponsoring&&entries.some(x=>x.delivery_date>"2026-12-18")){
      $("#rsvpNote").textContent="The sponsorship delivery date cannot be later than 18 December 2026.";return;
    }
    const first=entries[0];
    const payload={full_name:raw.full_name,email:raw.email,attendance_decision:raw.attendance_decision,
      is_sponsoring:sponsoring,sponsored_category_id:sponsoring?first.category_id:null,
      sponsored_item:sponsoring?first.sponsored_item:null,sponsorship_delivery_date:sponsoring?first.delivery_date:null};
    const {error}=await client.rpc("submit_gala_rsvp",{p_rsvp:payload,p_sponsorships:entries.map(x=>({category_id:x.category_id,sponsored_item:x.sponsored_item,delivery_date:x.delivery_date}))});
    if(error){$("#rsvpNote").textContent=error.code==="23505"?"An RSVP with this email already exists. Please contact the school if you need to change your response.":(error.message||"Unable to submit your RSVP. Please try again.");return;}
    form.reset();sponsorFields.hidden=true;sponsorshipEntries.innerHTML="";sponsorshipEntryCount=0;
    $("#rsvpNote").textContent="Thank you. Your RSVP and sponsorship commitments have been received.";
    toast("RSVP submitted successfully.");
  });
  loadSettings();loadProgramme();loadGallery();loadAwards();
})();