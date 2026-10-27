<!DOCTYPE html>
<html lang="en" class="h-full bg-slate-900">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CARGOO — Live App Preview (Every Load. Every Journey.)</title>
    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Leaflet Real Map CSS & JS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        body {
            font-family: "Segoe UI Variable", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background-color: #0b1120;
        }
        .phone-case {
            width: 395px;
            height: 840px;
            background: #1e293b;
            border-radius: 52px;
            padding: 12px;
            box-shadow: 0 25px 70px -15px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.12), inset 0 0 0 2px rgba(255, 255, 255, 0.05);
            position: relative;
            user-select: none;
        }
        .phone-screen {
            width: 100%;
            height: 100%;
            background-color: #F2F5F1;
            border-radius: 42px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            position: relative;
        }
        #leaflet-map {
            width: 100%;
            height: 100%;
            position: absolute;
            top: 0;
            left: 0;
            z-index: 1;
        }
        .hide-scrollbar::-webkit-scrollbar {
            display: none;
        }
        .hide-scrollbar {
            -ms-overflow-style: none;
            scrollbar-width: none;
        }
    </style>
</head>
<body class="min-h-full flex flex-col items-center justify-center p-4">

    <!-- Top Mode Switcher Bar -->
    <div class="mb-4 flex items-center justify-between w-full max-w-[420px] px-2 text-xs">
        <div class="flex items-center space-x-2">
            <span class="w-2.5 h-2.5 rounded-full bg-[#4B7B9F] animate-pulse"></span>
            <span class="font-extrabold text-slate-100 tracking-wider">CARGOO LIVE PREVIEW</span>
        </div>
        <!-- Screen Quick Switchers -->
        <div class="flex items-center space-x-1 bg-slate-800 p-1 rounded-xl border border-slate-700">
            <button onclick="switchScreen('home')" id="tab-btn-home" class="px-2.5 py-1 rounded-lg text-xs font-bold bg-[#4B7B9F] text-white transition">Dashboard</button>
            <button onclick="switchScreen('route')" id="tab-btn-route" class="px-2.5 py-1 rounded-lg text-xs font-bold text-slate-400 hover:text-white transition">Route</button>
            <button onclick="switchScreen('map')" id="tab-btn-map" class="px-2.5 py-1 rounded-lg text-xs font-bold text-slate-400 hover:text-white transition">Google Map</button>
            <button onclick="switchScreen('activity')" id="tab-btn-activity" class="px-2.5 py-1 rounded-lg text-xs font-bold text-slate-400 hover:text-white transition">Activity</button>
            <button onclick="switchScreen('reg')" id="tab-btn-reg" class="px-2.5 py-1 rounded-lg text-xs font-bold text-slate-400 hover:text-white transition">NIDA</button>
        </div>
    </div>

    <!-- The Samsung / Modern Phone Frame -->
    <div class="phone-case">
        <!-- Punch Hole Camera & Speaker -->
        <div class="absolute top-5 left-1/2 -translate-x-1/2 w-28 h-5 bg-[#1e293b] rounded-full z-50 flex items-center justify-center space-x-2">
            <div class="w-2.5 h-2.5 rounded-full bg-black border border-slate-700/50"></div>
            <div class="w-10 h-1 rounded-full bg-slate-800"></div>
        </div>

        <!-- Inner Phone Screen -->
        <div class="phone-screen shadow-inner">

            <!-- ========================================================== -->
            <!-- SCREEN 1: MAIN DASHBOARD / HOME                           -->
            <!-- ========================================================== -->
            <div id="screen-home" class="flex-1 flex flex-col h-full overflow-hidden bg-[#F2F5F1]">
                <!-- Status Bar Spacer -->
                <div class="h-10"></div>

                <!-- Main Scrollable Content -->
                <div class="flex-1 overflow-y-auto px-4 py-2 space-y-4 hide-scrollbar">
                    <!-- Top Brand Bar & Greeting -->
                    <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-2 bg-[#4B7B9F]/10 px-3 py-1.5 rounded-xl border border-[#4B7B9F]/20">
                            <span class="text-[#4B7B9F] font-black text-xs tracking-wider">CARGOO</span>
                        </div>
                        <div class="flex items-center space-x-2">
                            <span class="text-xs font-bold text-slate-800">Hello, Juma</span>
                            <div class="w-7 h-7 rounded-full bg-white border border-[#CAD4CC] flex items-center justify-center text-xs shadow-sm text-slate-600">
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>
                            </div>
                        </div>
                    </div>

                    <!-- Top Promo Banner -->
                    <div class="bg-gradient-to-br from-[#4B7B9F] to-[#3B6482] text-white p-4 rounded-2xl shadow-md relative overflow-hidden">
                        <div class="relative z-10 pr-12">
                            <span class="bg-amber-400 text-amber-950 font-black text-[9.5px] px-2 py-0.5 rounded-md uppercase tracking-wider">SPECIAL PROMO</span>
                            <h3 class="text-base font-black mt-2 leading-tight">Get 20% Off Cargo Delivery</h3>
                            <p class="text-xs text-slate-100 mt-1">On scheduled freight & on-demand trips this week.</p>
                        </div>
                        <div class="absolute right-3 bottom-2 text-3xl opacity-30 text-white font-black">CARGOO</div>
                    </div>

                    <!-- Headline & Subtitle -->
                    <div>
                        <h2 class="text-lg font-black text-[#1E2822] tracking-tight">Reliable Freight Transit, Anytime.</h2>
                        <p class="text-xs text-slate-500 mt-0.5">Select a vehicle suited for your cargo weight & size:</p>
                    </div>

                    <!-- 4-Card Service Grid -->
                    <div class="grid grid-cols-2 gap-2.5">
                        <!-- Cargo -->
                        <div onclick="switchScreen('route')" class="bg-white border border-[#CAD4CC] rounded-2xl p-3 flex flex-col justify-between h-24 hover:border-[#4B7B9F] cursor-pointer shadow-sm active:scale-95 transition">
                            <div class="flex items-center justify-between">
                                <div class="w-8 h-8 rounded-xl bg-[#4B7B9F]/10 text-[#4B7B9F] flex items-center justify-center">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0"/></svg>
                                </div>
                                <span class="bg-slate-100 text-[9px] font-extrabold text-slate-600 px-1.5 py-0.5 rounded">Instant</span>
                            </div>
                            <div>
                                <div class="text-xs font-black text-slate-900">Cargo Freight</div>
                                <div class="text-[10px] text-slate-500 truncate">Book on-demand transit</div>
                            </div>
                        </div>

                        <!-- Schedule Trip -->
                        <div onclick="switchScreen('route')" class="bg-white border border-[#CAD4CC] rounded-2xl p-3 flex flex-col justify-between h-24 hover:border-[#4B7B9F] cursor-pointer shadow-sm active:scale-95 transition">
                            <div class="flex items-center justify-between">
                                <div class="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                                </div>
                                <span class="bg-slate-100 text-[9px] font-extrabold text-slate-600 px-1.5 py-0.5 rounded">Schedule</span>
                            </div>
                            <div>
                                <div class="text-xs font-black text-slate-900">Book in Advance</div>
                                <div class="text-[10px] text-slate-500 truncate">Plan for later today</div>
                            </div>
                        </div>

                        <!-- Guta & Kirikuu -->
                        <div onclick="switchScreen('route')" class="bg-white border border-[#CAD4CC] rounded-2xl p-3 flex flex-col justify-between h-24 hover:border-[#4B7B9F] cursor-pointer shadow-sm active:scale-95 transition">
                            <div class="flex items-center justify-between">
                                <div class="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
                                </div>
                                <span class="bg-slate-100 text-[9px] font-extrabold text-slate-600 px-1.5 py-0.5 rounded">Quick</span>
                            </div>
                            <div>
                                <div class="text-xs font-black text-slate-900">Guta & Kirikuu</div>
                                <div class="text-[10px] text-slate-500 truncate">Small to medium loads</div>
                            </div>
                        </div>

                        <!-- Fuso & Scania -->
                        <div onclick="switchScreen('route')" class="bg-white border border-[#CAD4CC] rounded-2xl p-3 flex flex-col justify-between h-24 hover:border-[#4B7B9F] cursor-pointer shadow-sm active:scale-95 transition">
                            <div class="flex items-center justify-between">
                                <div class="w-8 h-8 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
                                </div>
                                <span class="bg-slate-100 text-[9px] font-extrabold text-slate-600 px-1.5 py-0.5 rounded">Up to 28T</span>
                            </div>
                            <div>
                                <div class="text-xs font-black text-slate-900">Fuso & Scania</div>
                                <div class="text-[10px] text-slate-500 truncate">Heavy commercial haul</div>
                            </div>
                        </div>
                    </div>

                    <!-- Where to? Search Bar -->
                    <div onclick="switchScreen('route')" class="bg-white border border-[#CAD4CC] rounded-2xl p-3 px-4 shadow-sm flex items-center justify-between cursor-pointer hover:border-[#4B7B9F] transition">
                        <div class="flex items-center space-x-3">
                            <svg class="w-4 h-4 text-[#4B7B9F]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
                            <span class="text-sm font-bold text-slate-900">Where to send cargo?</span>
                        </div>
                        <div class="bg-slate-100 px-2.5 py-1 rounded-xl flex items-center space-x-1 text-slate-700 text-xs font-black">
                            <svg class="w-3 h-3 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                            <span>Later</span>
                        </div>
                    </div>

                    <!-- Active Cargo Status Card (Dynamic, NO hardcoded fake destinations) -->
                    <div class="bg-white border border-[#CAD4CC] rounded-2xl p-4 shadow-sm space-y-3">
                        <div class="flex items-center justify-between">
                            <div class="flex items-center space-x-2.5">
                                <div class="w-8 h-8 rounded-xl bg-[#E5EEF5] flex items-center justify-center text-[#4B7B9F]">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 4H6a2 2 0 00-2 2v12a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-2m-4-1v8m0 0l3-3m-3 3L9 8m-5 5h2.586a1 1 0 01.707.293l2.414 2.414a1 1 0 00.707.293h3.172a1 1 0 00.707-.293l2.414-2.414a1 1 0 01.707-.293H20"/></svg>
                                </div>
                                <span class="text-xs font-black text-slate-900">Cargo Dispatch Ready</span>
                            </div>
                            <span class="bg-[#F2F5F1] text-[#4B7B9F] text-[10px] font-black px-2 py-0.5 rounded-md">Live GPS</span>
                        </div>
                        <p class="text-[11px] text-slate-500 leading-relaxed">
                            Need to move cargo or equipment? Tap "Where to send cargo?" above to enter any pickup & dropoff in Tanzania with instant fare estimation and live driver tracking.
                        </p>
                        <div class="grid grid-cols-2 gap-2 pt-1">
                            <button onclick="switchScreen('route')" class="py-2 px-3 border border-[#CAD4CC] rounded-xl text-xs font-bold text-[#4B7B9F] flex items-center justify-center space-x-1 hover:bg-[#F2F5F1] transition">
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/></svg>
                                <span>Send Cargo</span>
                            </button>
                            <button onclick="switchScreen('activity')" class="py-2 px-3 border border-[#CAD4CC] rounded-xl text-xs font-bold text-slate-700 flex items-center justify-center space-x-1 hover:bg-[#F2F5F1] transition">
                                <svg class="w-3.5 h-3.5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                <span>Shipment Log</span>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Bottom Navigation Bar (Home, Activity, Account) -->
                <div class="bg-white border-t border-[#CAD4CC] px-6 pt-2 pb-1 flex items-center justify-between text-xs z-30">
                    <button class="flex flex-col items-center text-[#4B7B9F] font-black">
                        <svg class="w-5 h-5 mb-0.5" fill="currentColor" viewBox="0 0 20 20"><path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"/></svg>
                        <span class="text-[10px]">Home</span>
                    </button>
                    <button onclick="switchScreen('activity')" class="flex flex-col items-center text-slate-400 hover:text-slate-700 font-bold">
                        <svg class="w-5 h-5 mb-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
                        <span class="text-[10px]">Activity</span>
                    </button>
                    <button onclick="switchScreen('reg')" class="flex flex-col items-center text-slate-400 hover:text-slate-700 font-bold">
                        <svg class="w-5 h-5 mb-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                        <span class="text-[10px]">Account</span>
                    </button>
                </div>
                <!-- Edge-to-Edge Android 3-Button System Navigation Bar (Pure White Background like Bolt Image 2) -->
                <div class="bg-white flex items-center justify-around py-1.5 pb-2 text-slate-400 z-30">
                    <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>
                    <div class="w-3.5 h-3.5 rounded-full border-2 border-slate-400"></div>
                    <div class="w-3 h-3 rounded-sm border-2 border-slate-400"></div>
                </div>
            </div>


            <!-- ========================================================== -->
            <!-- SCREEN 2: ROUTE SEARCH                                     -->
            <!-- ========================================================== -->
            <div id="screen-route" class="flex-1 flex flex-col h-full overflow-hidden bg-white hidden">
                <div class="h-10"></div>
                <!-- Route Header -->
                <div class="px-4 py-2 flex items-center space-x-3 border-b border-slate-100">
                    <button onclick="switchScreen('home')" class="text-slate-800 text-xl font-bold p-1">✕</button>
                    <span class="text-lg font-black text-slate-900">Route</span>
                </div>

                <!-- Pickup & Dropoff Input Block -->
                <div class="p-4 bg-slate-50 border-b border-slate-200">
                    <div class="bg-white rounded-2xl p-3 border border-[#CAD4CC] space-y-2 shadow-sm">
                        <!-- Pickup Field Row -->
                        <div onclick="setSearchFocus('pickup')" id="pickup-field-box" class="flex items-center space-x-3 p-1.5 rounded-xl border border-transparent hover:border-[#4B7B9F]/40 cursor-pointer">
                            <div class="w-3 h-3 rounded-full bg-[#4B7B9F] flex-shrink-0"></div>
                            <div class="flex-1 min-w-0">
                                <div class="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Pickup Location</div>
                                <input type="text" id="route-pickup-input" oninput="handleSearchInput(this.value)" value="63 Sam Nujoma Rd, Mwenge, Dar es Salaam" class="w-full text-xs font-bold text-slate-800 bg-transparent outline-none truncate" placeholder="Enter pickup address or landmark" />
                            </div>
                            <span id="pickup-active-badge" class="hidden text-[9px] font-black text-white bg-[#4B7B9F] px-1.5 py-0.5 rounded">Active</span>
                        </div>

                        <div class="border-t border-slate-100 mx-6"></div>

                        <!-- Dropoff Field Row -->
                        <div onclick="setSearchFocus('dropoff')" id="dropoff-field-box" class="flex items-center space-x-3 p-1.5 rounded-xl border border-[#4B7B9F] bg-[#4B7B9F]/5 cursor-pointer">
                            <div class="w-3 h-3 rounded-full bg-red-600 flex-shrink-0"></div>
                            <div class="flex-1 min-w-0">
                                <div class="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Dropoff Destination</div>
                                <input type="text" id="route-dropoff-input" oninput="handleSearchInput(this.value)" autofocus class="w-full text-xs font-black text-slate-900 bg-transparent outline-none truncate" placeholder="Where to send cargo in Tanzania?" />
                            </div>
                            <span id="dropoff-active-badge" class="text-[9px] font-black text-white bg-[#4B7B9F] px-1.5 py-0.5 rounded">Active</span>
                        </div>
                    </div>

                    <!-- Shortcut Pills -->
                    <div class="flex items-center space-x-2 mt-3">
                        <button onclick="startTripWithLocation('Select on Map', -6.7710, 39.2380)" class="flex-1 py-1.5 px-3 bg-white border border-[#CAD4CC] rounded-xl text-[11px] font-bold text-slate-700 flex items-center justify-center space-x-1.5 hover:border-[#4B7B9F]">
                            <svg class="w-3.5 h-3.5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/></svg>
                            <span>Pick on Map</span>
                        </button>
                        <button onclick="clearRecentSearches()" class="py-1.5 px-3 bg-white border border-[#CAD4CC] rounded-xl text-[11px] font-bold text-slate-700 flex items-center justify-center space-x-1.5">
                            <span>Clear Recent</span>
                        </button>
                    </div>
                </div>

                <!-- Searching Spinner Indicator -->
                <div id="route-search-loading" class="hidden px-4 py-3 flex items-center space-x-2 text-xs text-[#4B7B9F] font-bold">
                    <svg class="animate-spin h-4 w-4 text-[#4B7B9F]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
                    </svg>
                    <span>Searching Tanzania locations...</span>
                </div>

                <!-- Header for list: Recent vs Search Results -->
                <div id="route-list-header" class="px-4 py-2 text-[11px] font-extrabold text-slate-400 uppercase tracking-wider bg-slate-50 border-b border-slate-100 flex items-center justify-between">
                    <span id="route-list-title">Recent Searches</span>
                </div>

                <!-- Places / Results List -->
                <div id="route-places-list" class="flex-1 overflow-y-auto px-4 divide-y divide-slate-100">
                    <!-- Populated dynamically -->
                </div>
            </div>


            <!-- ========================================================== -->
            <!-- SCREEN 3: GOOGLE MAP LIVE ROUTE & DRAGGABLE SHEET          -->
            <!-- ========================================================== -->
            <div id="screen-map" class="flex-1 flex flex-col h-full overflow-hidden relative hidden">
                <!-- Leaflet with Google Maps Tiles -->
                <div id="leaflet-map"></div>

                <!-- Top Floating Route Bar -->
                <div class="absolute top-10 left-3 right-3 z-30">
                    <div class="bg-white rounded-2xl shadow-lg border border-[#CAD4CC] p-2.5 px-3.5 flex items-center justify-between">
                        <button onclick="switchScreen('home')" class="text-slate-800 font-black text-sm mr-2">←</button>
                        <div onclick="switchScreen('route')" class="flex-1 flex flex-col justify-center cursor-pointer min-w-0 pr-2">
                            <div class="flex items-center space-x-1.5 text-[11px] font-bold text-slate-600 truncate">
                                <span class="w-1.5 h-1.5 rounded-full bg-[#4B7B9F] flex-shrink-0"></span>
                                <span id="map-pickup-name" class="truncate">63 Sam Nujoma Rd, Mwenge</span>
                            </div>
                            <div class="flex items-center space-x-1.5 text-xs font-black text-[#0F172A] truncate">
                                <span class="w-1.5 h-1.5 rounded-full bg-red-600 flex-shrink-0"></span>
                                <span id="map-target-name" class="truncate">Kariakoo Market, Dar es Salaam</span>
                            </div>
                        </div>
                        <button onclick="switchScreen('route')" class="bg-[#EBF1F5] hover:bg-[#CAD4CC]/30 text-[#4B7B9F] text-[11px] font-black px-2.5 py-1 rounded-xl flex items-center space-x-1 border border-[#CAD4CC]">
                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/></svg>
                            <span>Change</span>
                        </button>
                    </div>
                </div>

                <!-- Floating Map Controls (Recenter Only - No +/- zoom buttons per mandate) -->
                <div class="absolute right-3.5 bottom-64 z-20 flex flex-col space-y-2">
                    <button onclick="recenterMap()" title="My Location" class="w-10 h-10 bg-white rounded-full shadow-lg flex items-center justify-center text-[#4B7B9F] border border-[#CAD4CC] hover:bg-slate-50 transition">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    </button>
                </div>

                <!-- Draggable / Collapsible Bottom Vehicle Sheet -->
                <div id="bottom-sheet" class="absolute bottom-0 left-0 right-0 z-30 transition-transform duration-300 ease-out select-none">
                    <div class="w-full bg-[#4B7B9F] text-white py-1 px-4 text-center text-xs font-bold rounded-t-2xl flex items-center justify-between shadow-sm cursor-pointer" onclick="toggleSheet()">
                        <span class="flex items-center space-x-1.5 mx-auto">
                            <span>20% CARGOO discount applied</span>
                        </span>
                        <button class="text-white/80 hover:text-white text-xs font-bold px-1.5 py-0.5 rounded bg-white/10">
                            <span id="banner-chevron">⌵</span>
                        </button>
                    </div>

                    <div class="bg-white rounded-t-3xl shadow-2xl p-4 pt-2 space-y-2 border-t border-[#CAD4CC]">
                        <div id="sheet-drag-area" onclick="toggleSheet()" class="cursor-pointer py-1.5 px-2 flex items-center justify-between text-xs text-slate-600 hover:bg-slate-50 rounded-xl transition">
                            <span class="font-black text-[11px] text-[#4B7B9F]">Choose Cargo Vehicle</span>
                            <div class="w-10 h-1 bg-slate-300 rounded-full"></div>
                            <span id="sheet-toggle-icon" class="text-xs font-bold text-slate-400">⌵</span>
                        </div>

                        <!-- 5 Cargo Vehicles: Guta, Kirikuu, Canter, Fuso, Scania -->
                        <div id="vehicle-list-box" class="space-y-2 max-h-56 overflow-y-auto pr-1">
                            <!-- 0. Guta -->
                            <div id="card-0" onclick="selectVehicle(0, 'Guta Cargo', 'TZS 5,000')" class="border-2 border-[#4B7B9F] bg-[#EBF1F5] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition">
                                <div class="flex items-center space-x-2.5">
                                    <div class="w-12 h-10 bg-amber-100 rounded-xl flex items-center justify-center font-bold text-amber-700 text-xs">GUTA</div>
                                    <div>
                                        <div class="text-xs font-black text-slate-900">Guta Cargo (3-Wheel)</div>
                                        <div class="text-[10px] text-slate-500">3 mins • 500 kg capacity</div>
                                    </div>
                                </div>
                                <div class="text-right">
                                    <div class="text-xs font-black text-slate-900">TZS 5,000</div>
                                    <div class="text-[9px] text-slate-400 line-through">TZS 7,000</div>
                                </div>
                            </div>

                            <!-- 1. Kirikuu -->
                            <div id="card-1" onclick="selectVehicle(1, 'Kirikuu Pick-up', 'TZS 12,000')" class="border border-[#CAD4CC] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition hover:border-[#4B7B9F]">
                                <div class="flex items-center space-x-2.5">
                                    <div class="w-12 h-10 bg-blue-100 rounded-xl flex items-center justify-center font-bold text-blue-700 text-xs">PICKUP</div>
                                    <div>
                                        <div class="text-xs font-black text-slate-900">Kirikuu Pick-up (Suzuki)</div>
                                        <div class="text-[10px] text-slate-500">5 mins • 1.2 Ton capacity</div>
                                    </div>
                                </div>
                                <div class="text-right">
                                    <div class="text-xs font-black text-slate-900">TZS 12,000</div>
                                    <div class="text-[9px] text-slate-400 line-through">TZS 15,000</div>
                                </div>
                            </div>

                            <!-- 2. Canter -->
                            <div id="card-2" onclick="selectVehicle(2, 'Canter Truck', 'TZS 28,000')" class="border border-[#CAD4CC] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition hover:border-[#4B7B9F]">
                                <div class="flex items-center space-x-2.5">
                                    <div class="w-12 h-10 bg-indigo-100 rounded-xl flex items-center justify-center font-bold text-indigo-700 text-xs">CANTER</div>
                                    <div>
                                        <div class="text-xs font-black text-slate-900">Canter Truck</div>
                                        <div class="text-[10px] text-slate-500">8 mins • 3.5 Ton capacity</div>
                                    </div>
                                </div>
                                <div class="text-right">
                                    <div class="text-xs font-black text-slate-900">TZS 28,000</div>
                                    <div class="text-[9px] text-slate-400 line-through">TZS 35,000</div>
                                </div>
                            </div>

                            <!-- 3. Fuso -->
                            <div id="card-3" onclick="selectVehicle(3, 'Fuso Fighter', 'TZS 65,000')" class="border border-[#CAD4CC] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition hover:border-[#4B7B9F]">
                                <div class="flex items-center space-x-2.5">
                                    <div class="w-12 h-10 bg-orange-100 rounded-xl flex items-center justify-center font-bold text-orange-700 text-xs">FUSO</div>
                                    <div>
                                        <div class="text-xs font-black text-slate-900">Fuso Fighter</div>
                                        <div class="text-[10px] text-slate-500">12 mins • 7.5 Ton capacity</div>
                                    </div>
                                </div>
                                <div class="text-right">
                                    <div class="text-xs font-black text-slate-900">TZS 65,000</div>
                                    <div class="text-[9px] text-slate-400 line-through">TZS 80,000</div>
                                </div>
                            </div>

                            <!-- 4. Scania -->
                            <div id="card-4" onclick="selectVehicle(4, 'Scania Semi-Trailer', 'TZS 160,000')" class="border border-[#CAD4CC] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition hover:border-[#4B7B9F]">
                                <div class="flex items-center space-x-2.5">
                                    <div class="w-12 h-10 bg-red-100 rounded-xl flex items-center justify-center font-bold text-red-700 text-xs">SCANIA</div>
                                    <div>
                                        <div class="text-xs font-black text-slate-900">Scania Semi-Trailer</div>
                                        <div class="text-[10px] text-slate-500">18 mins • 28 Ton capacity</div>
                                    </div>
                                </div>
                                <div class="text-right">
                                    <div class="text-xs font-black text-slate-900">TZS 160,000</div>
                                    <div class="text-[9px] text-slate-400 line-through">TZS 190,000</div>
                                </div>
                            </div>
                        </div>

                        <!-- Cargo Contact Persons & Order for Someone Else -->
                        <div onclick="openContactModal()" class="bg-[#F8FAFC] border border-[#CAD4CC] rounded-2xl p-2.5 px-3 flex items-center justify-between cursor-pointer hover:border-[#4B7B9F] transition">
                            <div class="flex items-center space-x-2.5 min-w-0">
                                <svg class="w-5 h-5 text-[#4B7B9F] flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                                <div class="min-w-0">
                                    <div class="flex items-center space-x-1.5">
                                        <span class="text-xs font-bold text-slate-900">Cargo Contact Persons</span>
                                        <span id="contact-badge" class="hidden text-[9px] font-black text-green-700 bg-green-100 px-1.5 py-0.5 rounded">Custom Contact</span>
                                    </div>
                                    <div id="contact-summary" class="text-[10px] text-slate-500 truncate">Ordering for someone else? Tap to set contacts</div>
                                </div>
                            </div>
                            <svg class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
                        </div>

                        <!-- Payment & Booking Button -->
                        <div class="pt-2">
                            <div class="flex items-center space-x-1.5 text-xs font-bold text-slate-800 mb-2">
                                <span class="text-[#4B7B9F]">Payment:</span>
                                <span>Cash Payment</span>
                            </div>
                            <button id="btn-select" onclick="confirmCargoBooking()" class="w-full bg-[#4B7B9F] hover:bg-[#3B6482] text-white py-3 rounded-2xl font-black text-sm tracking-wide shadow-md transition">
                                Book Guta Cargo (TZS 5,000)
                            </button>
                        </div>
                    </div>
                </div>
            </div>


            <!-- ========================================================== -->
            <!-- SCREEN 4: ACTIVITY (NO DUMMY TRIPS PER MANDATE)            -->
            <!-- ========================================================== -->
            <div id="screen-activity" class="flex-1 flex flex-col h-full overflow-hidden bg-[#F2F5F1] hidden">
                <div class="h-10"></div>
                <div class="px-4 py-2 flex items-center justify-between border-b border-[#CAD4CC] bg-white">
                    <button onclick="switchScreen('home')" class="text-slate-800 text-lg font-bold">←</button>
                    <span class="text-sm font-black text-slate-900">Activity</span>
                    <span class="text-xs text-[#4B7B9F] font-bold">CARGOO</span>
                </div>

                <div class="flex-1 flex flex-col items-center justify-center p-6 text-center">
                    <div class="w-16 h-16 rounded-2xl bg-white border border-[#CAD4CC] flex items-center justify-center text-[#4B7B9F] shadow-sm mb-4">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/></svg>
                    </div>
                    <h3 class="text-base font-black text-slate-900 mb-1">No Recent Activity</h3>
                    <p class="text-xs text-slate-500 max-w-xs mb-6">Your completed cargo deliveries and transit receipts will appear here.</p>
                    <button onclick="switchScreen('route')" class="px-5 py-2.5 bg-[#4B7B9F] text-white rounded-xl text-xs font-bold shadow-sm">
                        Request Cargo Transit
                    </button>
                </div>
            </div>


            <!-- ========================================================== -->
            <!-- SCREEN 5: NIDA REGISTRATION & PROFILE (USER SPECIFICATION) -->
            <!-- ========================================================== -->
            <div id="screen-reg" class="flex-1 flex flex-col h-full overflow-hidden bg-[#F2F5F1] hidden">
                <div class="h-10"></div>
                <div class="px-4 py-2 flex items-center justify-between border-b border-[#CAD4CC] bg-white">
                    <button onclick="switchScreen('home')" class="text-slate-800 text-lg font-bold">←</button>
                    <span class="text-sm font-black text-slate-900">Account Profile & NIDA</span>
                    <span class="text-xs text-[#4B7B9F] font-bold">CARGOO</span>
                </div>

                <div class="flex-1 overflow-y-auto p-4 space-y-4">
                    <div>
                        <h2 class="text-xl font-black text-slate-900">Your Information</h2>
                        <p class="text-xs text-slate-500 mt-1">Registration requires your 20-digit National ID (NIDA) for legal transit security. Your city is automatically detected via live GPS.</p>
                    </div>

                    <div class="space-y-3">
                        <div>
                            <label class="block text-xs font-bold text-slate-700 mb-1">Full Name *</label>
                            <input type="text" id="reg-name" value="Juma Rashid Bakari" class="w-full p-3 bg-white border border-[#CAD4CC] rounded-xl text-xs font-bold text-slate-900 outline-none" />
                        </div>

                        <div>
                            <div class="flex justify-between items-center mb-1">
                                <label class="text-xs font-bold text-slate-700">NIDA Number (National ID) *</label>
                                <span class="text-[10px] font-bold text-[#4B7B9F]">20 / 20 Digits</span>
                            </div>
                            <input type="text" maxlength="20" id="reg-nida" value="19900101123450000120" class="w-full p-3 bg-white border-2 border-[#4B7B9F] rounded-xl text-xs font-mono font-bold text-slate-900 outline-none" />
                            <p class="text-[10px] text-[#4B7B9F] font-semibold mt-1">20-digit NIDA format verified.</p>
                        </div>

                        <div>
                            <label class="block text-xs font-bold text-slate-700 mb-1">Email Address (Optional)</label>
                            <input type="email" id="reg-email" value="juma@example.com" class="w-full p-3 bg-white border border-[#CAD4CC] rounded-xl text-xs text-slate-900 outline-none" />
                        </div>

                        <!-- GPS location dynamic alert -->
                        <div class="p-3 bg-[#EBF1F5] border border-[#CAD4CC] rounded-xl flex items-center space-x-2 text-xs text-slate-800">
                            <svg class="w-5 h-5 text-[#4B7B9F]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                            <div>
                                <div class="font-bold">Live GPS Detected Location:</div>
                                <div class="text-[11px] text-[#4B7B9F] font-semibold">63 Sam Nujoma Rd, Mwenge, Dar es Salaam</div>
                            </div>
                        </div>
                    </div>

                    <button onclick="alert('Account profile saved successfully!'); switchScreen('home')" class="w-full bg-[#4B7B9F] text-white py-3 rounded-2xl font-black text-xs tracking-wider shadow-md">
                        Save & Continue to CARGOO
                    </button>
                </div>
            </div>

            <!-- Cargo Contacts Modal Sheet -->
            <div id="modal-contacts" class="hidden absolute inset-0 z-50 bg-black/60 flex flex-col justify-end rounded-[42px] overflow-hidden">
                <div class="bg-white rounded-t-3xl p-4 space-y-3 shadow-2xl">
                    <div class="flex items-center justify-between pb-1 border-b border-slate-100">
                        <div class="flex items-center space-x-2">
                            <svg class="w-4 h-4 text-[#4B7B9F]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                            <span class="text-xs font-black text-slate-900">Cargo Contacts & Order for Others</span>
                        </div>
                        <button onclick="closeContactModal()" class="text-slate-400 font-bold hover:text-slate-700 text-sm">✕</button>
                    </div>
                    <p class="text-[10px] text-slate-500 leading-snug">
                        Dispatch cargo from anywhere in Tanzania. Driver will communicate directly with pickup and dropoff contact persons.
                    </p>

                    <!-- Sender Mode Switcher -->
                    <div class="grid grid-cols-2 gap-1 p-1 bg-slate-100 rounded-xl text-center text-xs font-bold">
                        <button id="sender-btn-self" onclick="setSenderMode('self')" class="py-1 rounded-lg bg-white text-[#4B7B9F] shadow-sm">I am the Sender</button>
                        <button id="sender-btn-other" onclick="setSenderMode('other')" class="py-1 rounded-lg text-slate-500">Someone Else at Pickup</button>
                    </div>

                    <div id="custom-sender-fields" class="hidden space-y-2">
                        <input type="text" id="contact-sender-name" placeholder="Sender Name at Pickup (e.g. Workshop, Store Manager)" class="w-full text-xs font-bold p-2 rounded-xl border border-slate-200 outline-none focus:border-[#4B7B9F]" />
                        <input type="tel" id="contact-sender-phone" placeholder="Sender Phone Number (e.g. 0712345678)" class="w-full text-xs font-bold p-2 rounded-xl border border-slate-200 outline-none focus:border-[#4B7B9F]" />
                    </div>

                    <div class="space-y-1.5 pt-1">
                        <div class="text-[10px] font-black uppercase text-slate-400">Recipient Contact (Dropoff)</div>
                        <input type="text" id="contact-recipient-name" placeholder="Recipient Full Name *" class="w-full text-xs font-bold p-2 rounded-xl border border-slate-200 outline-none focus:border-[#4B7B9F]" />
                        <input type="tel" id="contact-recipient-phone" placeholder="Recipient Phone Number *" class="w-full text-xs font-bold p-2 rounded-xl border border-slate-200 outline-none focus:border-[#4B7B9F]" />
                    </div>

                    <div class="space-y-1">
                        <div class="text-[10px] font-black uppercase text-slate-400">Cargo Description / Notes</div>
                        <input type="text" id="contact-cargo-notes" placeholder="e.g. 15 bags cement, Gate 2" class="w-full text-xs font-bold p-2 rounded-xl border border-slate-200 outline-none focus:border-[#4B7B9F]" />
                    </div>

                    <button onclick="saveContacts()" class="w-full py-2.5 bg-[#4B7B9F] hover:bg-[#3B6482] text-white rounded-xl text-xs font-black shadow transition">
                        Save Cargo Contacts
                    </button>
                </div>
            </div>

        </div>
    </div>

    <!-- Scripting for Live Preview -->
    <script>
        let currentSearchMode = 'dropoff'; // 'pickup' or 'dropoff'
        let pickupLocation = { name: '63 Sam Nujoma Rd, Mwenge, Dar es Salaam', lat: -6.7715, lng: 39.2399 };
        let dropoffLocation = { name: 'Kariakoo Market, Dar es Salaam', lat: -6.8200, lng: 39.2770 };

        // Cargo Contacts
        let isOrderingForOthers = false;
        let senderContact = { name: 'Myself', phone: '' };
        let recipientContact = { name: '', phone: '' };
        let cargoNotes = '';
        let selectedVehicleName = 'Guta Cargo';
        let selectedVehiclePrice = 'TZS 5,000';

        function switchScreen(screenName) {
            ['home', 'route', 'map', 'activity', 'reg'].forEach(s => {
                const el = document.getElementById(`screen-${s}`);
                const btn = document.getElementById(`tab-btn-${s}`);
                if (el) el.classList.add('hidden');
                if (btn) {
                    btn.classList.remove('bg-[#4B7B9F]', 'text-white');
                    btn.classList.add('text-slate-400');
                }
            });

            const activeEl = document.getElementById(`screen-${screenName}`);
            const activeBtn = document.getElementById(`tab-btn-${screenName}`);
            if (activeEl) activeEl.classList.remove('hidden');
            if (activeBtn) {
                activeBtn.classList.remove('text-slate-400');
                activeBtn.classList.add('bg-[#4B7B9F]', 'text-white');
            }

            if (screenName === 'map') {
                setTimeout(() => { map.invalidateSize(); }, 200);
            } else if (screenName === 'route') {
                renderRecentSearches();
            }
        }

        function setSearchFocus(mode) {
            currentSearchMode = mode;
            const pickupBox = document.getElementById('pickup-field-box');
            const dropoffBox = document.getElementById('dropoff-field-box');
            const pickupBadge = document.getElementById('pickup-active-badge');
            const dropoffBadge = document.getElementById('dropoff-active-badge');

            if (mode === 'pickup') {
                pickupBox.className = 'flex items-center space-x-3 p-1.5 rounded-xl border border-[#4B7B9F] bg-[#4B7B9F]/5 cursor-pointer';
                dropoffBox.className = 'flex items-center space-x-3 p-1.5 rounded-xl border border-transparent hover:border-[#4B7B9F]/40 cursor-pointer';
                pickupBadge.classList.remove('hidden');
                dropoffBadge.classList.add('hidden');
                document.getElementById('route-pickup-input').focus();
            } else {
                dropoffBox.className = 'flex items-center space-x-3 p-1.5 rounded-xl border border-[#4B7B9F] bg-[#4B7B9F]/5 cursor-pointer';
                pickupBox.className = 'flex items-center space-x-3 p-1.5 rounded-xl border border-transparent hover:border-[#4B7B9F]/40 cursor-pointer';
                dropoffBadge.classList.remove('hidden');
                pickupBadge.classList.add('hidden');
                document.getElementById('route-dropoff-input').focus();
            }
        }

        // Dynamic Recent Searches (from localStorage)
        function getRecentSearches() {
            try {
                const stored = localStorage.getItem('cargoo_recent_searches');
                return stored ? JSON.parse(stored) : [
                    { name: 'Kariakoo Market', subtitle: 'Msimbazi St, Kariakoo, Dar es Salaam', lat: -6.8200, lng: 39.2770, dist: '8.5 km' },
                    { name: 'Mwenge Bus Terminal', subtitle: 'Sam Nujoma Rd, Mwenge, Dar es Salaam', lat: -6.7710, lng: 39.2380, dist: '0.8 km' }
                ];
            } catch (e) {
                return [];
            }
        }

        function saveRecentSearch(name, subtitle, lat, lng) {
            try {
                let recents = getRecentSearches();
                recents = recents.filter(r => r.name !== name);
                const dKm = calculateDistance(-6.7715, 39.2399, lat, lng);
                recents.unshift({ name, subtitle, lat, lng, dist: `${dKm.toFixed(1)} km`, time: Date.now() });
                if (recents.length > 8) recents = recents.slice(0, 8);
                localStorage.setItem('cargoo_recent_searches', JSON.stringify(recents));
            } catch (e) {}
        }

        function clearRecentSearches() {
            try {
                localStorage.removeItem('cargoo_recent_searches');
            } catch (e) {}
            renderPlacesList([]);
        }

        function renderRecentSearches() {
            const listTitleEl = document.getElementById('route-list-title');
            if (listTitleEl) listTitleEl.innerText = 'Recent Searches';
            const recents = getRecentSearches();
            renderPlacesList(recents);
        }

        function calculateDistance(lat1, lon1, lat2, lon2) {
            const p = 0.017453292519943295;
            const c = Math.cos;
            const a = 0.5 - c((lat2 - lat1) * p)/2 +
                    c(lat1 * p) * c(lat2 * p) *
                    (1 - c((lon2 - lon1) * p))/2;
            return 12742 * Math.asin(Math.sqrt(a));
        }

        let searchDebounceTimer = null;
        function handleSearchInput(query) {
            clearTimeout(searchDebounceTimer);
            const q = query.trim();
            if (!q) {
                renderRecentSearches();
                return;
            }
            searchDebounceTimer = setTimeout(() => {
                fetchDynamicPlaces(q);
            }, 300);
        }

        async function fetchDynamicPlaces(query) {
            const loadingEl = document.getElementById('route-search-loading');
            const listTitleEl = document.getElementById('route-list-title');
            if (loadingEl) loadingEl.classList.remove('hidden');
            if (listTitleEl) listTitleEl.innerText = `Results for "${query}" (Tanzania)`;

            try {
                // Bias around user GPS location (Dar es Salaam -6.7715, 39.2399)
                const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(query)}&lat=-6.7715&lon=39.2399&limit=10`;
                const res = await fetch(url);
                const data = await res.json();
                const features = data.features || [];

                const results = features.map(f => {
                    const props = f.properties || {};
                    const coords = f.geometry && f.geometry.coordinates ? f.geometry.coordinates : [39.2399, -6.7715];
                    const name = props.name || props.street || props.district || props.city || query;
                    const parts = [];
                    if (props.street && props.street !== name) parts.push(props.street);
                    if (props.district) parts.push(props.district);
                    if (props.city && props.city !== props.district) parts.push(props.city);
                    if (props.state && props.state !== props.city) parts.push(props.state);
                    if (props.country) parts.push(props.country);
                    const subtitle = parts.join(', ') || 'Tanzania';

                    const dKm = calculateDistance(-6.7715, 39.2399, coords[1], coords[0]);
                    return {
                        name: name,
                        subtitle: subtitle,
                        lat: coords[1],
                        lng: coords[0],
                        dist: `${dKm.toFixed(1)} km`
                    };
                });

                renderPlacesList(results);
            } catch (err) {
                console.error('Dynamic geocoding error:', err);
            } finally {
                if (loadingEl) loadingEl.classList.add('hidden');
            }
        }

        function renderPlacesList(items) {
            const listEl = document.getElementById('route-places-list');
            if (!listEl) return;

            if (items.length === 0) {
                listEl.innerHTML = `
                    <div class="py-8 text-center text-xs text-slate-400">
                        Type any street, market, warehouse, or area name in Tanzania.
                    </div>
                `;
                return;
            }

            listEl.innerHTML = items.map(p => `
                <div onclick="selectLocationResult('${escapeJs(p.name)}', '${escapeJs(p.subtitle)}', ${p.lat}, ${p.lng})" class="py-2.5 flex items-center justify-between cursor-pointer hover:bg-slate-50 transition">
                    <div class="flex items-center space-x-3 min-w-0 pr-2">
                        <div class="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-slate-500 flex-shrink-0">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                        </div>
                        <div class="min-w-0">
                            <div class="text-xs font-black text-slate-900 truncate">${p.name}</div>
                            <div class="text-[10px] text-slate-500 truncate">${p.subtitle}</div>
                        </div>
                    </div>
                    <span class="bg-[#4B7B9F]/10 text-[#4B7B9F] text-[10px] font-black px-2 py-0.5 rounded-md flex-shrink-0">${p.dist || 'Local'}</span>
                </div>
            `).join('');
        }

        function escapeJs(str) {
            return (str || '').replace(/'/g, "\\'");
        }

        function selectLocationResult(name, subtitle, lat, lng) {
            saveRecentSearch(name, subtitle, lat, lng);

            if (currentSearchMode === 'pickup') {
                pickupLocation = { name, lat, lng };
                document.getElementById('route-pickup-input').value = name;
                document.getElementById('map-pickup-name').innerText = name;
                pickupCoords = [lat, lng];
                setSearchFocus('dropoff');
            } else {
                dropoffLocation = { name, lat, lng };
                document.getElementById('route-dropoff-input').value = name;
                document.getElementById('map-target-name').innerText = name;
                dropoffCoords = [lat, lng];
                switchScreen('map');
                rebuildMapRoute();
            }
        }

        function startTripWithLocation(name, lat, lng) {
            selectLocationResult(name, 'Tanzania', lat, lng);
        }

        // Contact Modal functions
        function openContactModal() {
            document.getElementById('modal-contacts').classList.remove('hidden');
        }

        function closeContactModal() {
            document.getElementById('modal-contacts').classList.add('hidden');
        }

        function setSenderMode(mode) {
            const btnSelf = document.getElementById('sender-btn-self');
            const btnOther = document.getElementById('sender-btn-other');
            const fields = document.getElementById('custom-sender-fields');

            if (mode === 'self') {
                btnSelf.className = 'py-1 rounded-lg bg-white text-[#4B7B9F] shadow-sm';
                btnOther.className = 'py-1 rounded-lg text-slate-500';
                fields.classList.add('hidden');
                senderContact.name = 'Myself';
                senderContact.phone = '';
            } else {
                btnOther.className = 'py-1 rounded-lg bg-white text-[#4B7B9F] shadow-sm';
                btnSelf.className = 'py-1 rounded-lg text-slate-500';
                fields.classList.remove('hidden');
            }
        }

        function saveContacts() {
            const senderNameInput = document.getElementById('contact-sender-name').value.trim();
            const senderPhoneInput = document.getElementById('contact-sender-phone').value.trim();
            const recipNameInput = document.getElementById('contact-recipient-name').value.trim();
            const recipPhoneInput = document.getElementById('contact-recipient-phone').value.trim();
            const notesInput = document.getElementById('contact-cargo-notes').value.trim();

            if (senderNameInput) {
                senderContact.name = senderNameInput;
                senderContact.phone = senderPhoneInput;
            }
            recipientContact.name = recipNameInput;
            recipientContact.phone = recipPhoneInput;
            cargoNotes = notesInput;

            isOrderingForOthers = (senderContact.name !== 'Myself') || !!recipientContact.name;

            const badgeEl = document.getElementById('contact-badge');
            const summaryEl = document.getElementById('contact-summary');

            if (isOrderingForOthers) {
                badgeEl.classList.remove('hidden');
                summaryEl.innerText = `Sender: ${senderContact.name} • Recipient: ${recipientContact.name || 'Set'}`;
                summaryEl.className = 'text-[10px] text-green-700 font-bold truncate';
            } else {
                badgeEl.classList.add('hidden');
                summaryEl.innerText = 'Ordering for someone else? Tap to set contacts';
                summaryEl.className = 'text-[10px] text-slate-500 truncate';
            }

            closeContactModal();
        }

        function confirmCargoBooking() {
            let msg = `CARGOO Booking Confirmed!\nVehicle: ${selectedVehicleName} (${selectedVehiclePrice})\nPickup: ${pickupLocation.name}\nDropoff: ${dropoffLocation.name}`;
            if (isOrderingForOthers) {
                msg += `\n\nSender at Pickup: ${senderContact.name} ${senderContact.phone ? '(' + senderContact.phone + ')' : ''}`;
                if (recipientContact.name) {
                    msg += `\nRecipient at Dropoff: ${recipientContact.name} (${recipientContact.phone})`;
                }
            }
            if (cargoNotes) {
                msg += `\nNotes: ${cargoNotes}`;
            }
            msg += `\n\nDriver dispatched! Live tracking active.`;
            alert(msg);
        }

        // ==========================================
        // LEAFLET MAP WITH OFFICIAL GOOGLE MAPS TILES
        // ==========================================
        let pickupCoords = [-6.7715, 39.2399]; // 63 Sam Nujoma Rd, Mwenge
        let dropoffCoords = [-6.8200, 39.2770]; // Kariakoo Market
        let polylineLayer = null;
        let pickupMarker = null;
        let dropoffMarker = null;

        const map = L.map('leaflet-map', {
            zoomControl: false,
            attributionControl: false
        }).setView(pickupCoords, 14.5);

        // Standard Google Maps Roadmap Tiles
        L.tileLayer('https://mt1.google.com/vt/lyrs=m&hl=en&x={x}&y={y}&z={z}', {
            subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
            maxZoom: 20
        }).addTo(map);

        function rebuildMapRoute() {
            if (polylineLayer) map.removeLayer(polylineLayer);
            if (pickupMarker) map.removeLayer(pickupMarker);
            if (dropoffMarker) map.removeLayer(dropoffMarker);

            const midLat = (pickupCoords[0] + dropoffCoords[0]) / 2;
            const midLng = (pickupCoords[1] + dropoffCoords[1]) / 2;

            const routePoints = [
                pickupCoords,
                [pickupCoords[0] * 0.7 + dropoffCoords[0] * 0.3, pickupCoords[1] * 0.7 + dropoffCoords[1] * 0.3],
                [midLat, midLng],
                [pickupCoords[0] * 0.3 + dropoffCoords[0] * 0.7, pickupCoords[1] * 0.3 + dropoffCoords[1] * 0.7],
                dropoffCoords
            ];

            polylineLayer = L.polyline(routePoints, {
                color: '#4B7B9F',
                weight: 6.0,
                opacity: 0.95,
                lineCap: 'round',
                lineJoin: 'round'
            }).addTo(map);

            const pickupIcon = L.divIcon({
                className: '',
                html: `<div style="width:16px; height:16px; background:#4B7B9F; border:3px solid white; border-radius:50%; box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
                iconSize: [16, 16],
                iconAnchor: [8, 8]
            });
            pickupMarker = L.marker(pickupCoords, { icon: pickupIcon }).addTo(map);

            const dropoffIcon = L.divIcon({
                className: '',
                html: `<div style="width:20px; height:20px; background:#EF4444; border:3px solid white; border-radius:50%; box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
                iconSize: [20, 20],
                iconAnchor: [10, 10]
            });
            dropoffMarker = L.marker(dropoffCoords, { icon: dropoffIcon }).addTo(map);

            map.fitBounds(L.latLngBounds([pickupCoords, dropoffCoords]), { padding: [50, 50] });
        }

        rebuildMapRoute();

        function recenterMap() {
            map.setView(pickupCoords, 14.5);
        }

        // Draggable Sheet Logic
        let currentSheetState = 'mid';
        const bottomSheetEl = document.getElementById('bottom-sheet');
        const sheetToggleIconEl = document.getElementById('sheet-toggle-icon');
        const bannerChevronEl = document.getElementById('banner-chevron');

        function toggleSheet() {
            if (currentSheetState === 'collapsed') {
                currentSheetState = 'mid';
                bottomSheetEl.style.transform = 'translateY(0)';
                if (sheetToggleIconEl) sheetToggleIconEl.innerText = '⌵';
                if (bannerChevronEl) bannerChevronEl.innerText = '⌵';
            } else {
                currentSheetState = 'collapsed';
                bottomSheetEl.style.transform = 'translateY(calc(100% - 64px))';
                if (sheetToggleIconEl) sheetToggleIconEl.innerText = '⌃';
                if (bannerChevronEl) bannerChevronEl.innerText = '⌃';
            }
        }

        function selectVehicle(idx, name, price) {
            selectedVehicleName = name;
            selectedVehiclePrice = price;
            [0, 1, 2, 3, 4].forEach(i => {
                const el = document.getElementById(`card-${i}`);
                if (el) {
                    if (i === idx) {
                        el.className = 'border-2 border-[#4B7B9F] bg-[#EBF1F5] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition';
                    } else {
                        el.className = 'border border-[#CAD4CC] rounded-2xl p-2.5 flex items-center justify-between cursor-pointer transition hover:border-[#4B7B9F]';
                    }
                }
            });
            document.getElementById('btn-select').innerText = `Book ${name} (${price})`;
        }
    </script>
</body>
</html>
