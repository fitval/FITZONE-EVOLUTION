const CACHE='fitzone-v8';

self.addEventListener('install',e=>{
  self.skipWaiting();
});

self.addEventListener('message',e=>{
  if(e.data&&e.data.type==='SKIP_WAITING')self.skipWaiting();
  // Force cache clear on demand
  if(e.data&&e.data.type==='CLEAR_CACHE'){
    e.waitUntil(caches.keys().then(keys=>Promise.all(keys.map(k=>caches.delete(k)))));
  }
});

self.addEventListener('activate',e=>{
  e.waitUntil(
    caches.keys().then(keys=>Promise.all(
      keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch',e=>{
  // Never cache version.json — always fetch from network
  if(e.request.url.includes('version.json')){
    e.respondWith(fetch(e.request,{cache:'no-store'}));
    return;
  }
  // Skip caching for API calls, non-GET, and chrome-extension
  if(e.request.method!=='GET'||e.request.url.includes('supabase.co')||e.request.url.includes('googleapis.com')||e.request.url.includes('script.google.com')||e.request.url.startsWith('chrome-extension')){
    return;
  }
  // Network first, fallback to cache (offline support)
  e.respondWith(
    fetch(e.request,{cache:'no-store'}).then(res=>{
      if(res.ok){
        const clone=res.clone();
        caches.open(CACHE).then(c=>c.put(e.request,clone));
      }
      return res;
    }).catch(()=>caches.match(e.request))
  );
});
