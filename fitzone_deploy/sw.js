const CACHE='fitzone-v7';

self.addEventListener('install',e=>{
  // Skip waiting immediately — new SW takes over right away
  self.skipWaiting();
});

self.addEventListener('message',e=>{
  if(e.data&&e.data.type==='SKIP_WAITING')self.skipWaiting();
});

self.addEventListener('activate',e=>{
  // Delete all old caches
  e.waitUntil(
    caches.keys().then(keys=>Promise.all(
      keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch',e=>{
  // Skip caching for API calls, non-GET, and chrome-extension
  if(e.request.method!=='GET'||e.request.url.includes('supabase.co')||e.request.url.includes('googleapis.com')||e.request.url.includes('script.google.com')||e.request.url.startsWith('chrome-extension')){
    return;
  }
  // Network first with no-cache header, fallback to cache (offline support)
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
