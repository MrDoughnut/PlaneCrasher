// sw.js

const CACHE_NAME = 'planecrasher-cache-v1';

// Add the names of all the files you want to work offline
const URLS_TO_CACHE = [
    '/',
    '/index.html',
    '/style.css',
    '/game.js',
    '/manifest.json',
    // Note: ensure these match exactly what you name them in your assets folder
    '/assets/explosion.wav',
    '/assets/background-music.mp3',
    '/assets/icon-192.png',
    '/assets/icon-512.png'
];

// Install Event - Caches the files
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('Opened cache');
                return cache.addAll(URLS_TO_CACHE);
            })
    );
});

// Fetch Event - Intercepts network requests and serves from cache if offline
self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                // Cache hit - return response
                if (response) {
                    return response;
                }
                
                // Not in cache - fetch from network
                return fetch(event.request).then(
                    (networkResponse) => {
                        // Check if we received a valid response
                        if(!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
                            return networkResponse;
                        }

                        // Clone the response because it's a stream and can only be consumed once
                        const responseToCache = networkResponse.clone();

                        caches.open(CACHE_NAME)
                            .then((cache) => {
                                cache.put(event.request, responseToCache);
                            });

                        return networkResponse;
                    }
                );
            })
    );
});

// Activate Event - Cleans up old, outdated caches when you push an update
self.addEventListener('activate', (event) => {
    const cacheWhitelist = [CACHE_NAME];
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheWhitelist.indexOf(cacheName) === -1) {
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
});