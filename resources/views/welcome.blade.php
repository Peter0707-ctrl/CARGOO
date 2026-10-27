<!DOCTYPE html>
<html lang="en" class="h-full">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CARGOO — Every Load. Every Journey.</title>
    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        cargoo: {
                            bg: '#F2F5F1',
                            primary: '#4B7B9F',
                            primaryHover: '#3C6C90',
                            primaryFade: '#E5EEF5',
                            charcoal: '#202622',
                            sage: '#61736A',
                            border: '#CAD4CC',
                            gold: '#D4AF37',
                        }
                    },
                    fontFamily: {
                        sans: ['"Segoe UI Variable"', 'Segoe UI', 'system-ui', '-apple-system', 'sans-serif'],
                    }
                }
            }
        }
    </script>
    <style>
        body {
            background-color: #F2F5F1;
            color: #202622;
            font-family: "Segoe UI Variable", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }
        .btn-cargoo {
            background-color: #4B7B9F;
            color: #ffffff;
            transition: all 0.2s ease-in-out;
        }
        .btn-cargoo:hover {
            background-color: #3C6C90;
            box-shadow: 0 4px 12px rgba(75, 123, 159, 0.25);
        }
    </style>
</head>
<body class="min-h-full flex flex-col justify-between selection:bg-sky-200">

    <!-- Top Navigation Bar -->
    <header class="border-b border-[#CAD4CC]/60 bg-[#F2F5F1]/90 backdrop-blur sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
            <div class="flex items-center space-x-3">
                <div class="w-10 h-10 rounded-xl bg-[#4B7B9F] flex items-center justify-center text-white font-black text-xl shadow-sm tracking-wider">
                    C
                </div>
                <div>
                    <span class="text-2xl font-black tracking-tight text-[#202622]">CARGOO</span>
                    <span class="hidden sm:inline-block ml-3 px-2 py-0.5 text-xs font-semibold rounded-full bg-[#E5EEF5] text-[#4B7B9F]">Tanzania</span>
                </div>
            </div>

            <nav class="hidden md:flex items-center space-x-8 text-sm font-semibold text-[#61736A]">
                <a href="#vehicles" class="hover:text-[#202622] transition">Vehicle Fleet</a>
                <a href="#how-it-works" class="hover:text-[#202622] transition">How It Works</a>
                <a href="/preview/phone" target="_blank" class="text-[#4B7B9F] flex items-center space-x-1 hover:underline">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/></svg>
                    <span>Mobile App Live Preview</span>
                </a>
            </nav>

            <div class="flex items-center space-x-3">
                <a href="/preview/phone" class="btn-cargoo px-5 py-2.5 rounded-xl font-bold text-sm flex items-center space-x-2">
                    <span>Book Cargo Transit</span>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/></svg>
                </a>
            </div>
        </div>
    </header>

    <!-- Hero Section -->
    <main class="flex-grow">
        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24 grid lg:grid-cols-12 gap-12 items-center">
            <div class="lg:col-span-7 space-y-6">
                <div class="inline-flex items-center space-x-2 px-3 py-1.5 rounded-full bg-[#E5EEF5] text-[#4B7B9F] text-xs font-bold uppercase tracking-wider">
                    <span>Official Motto: Every Load. Every Journey.</span>
                </div>
                <h1 class="text-4xl sm:text-5xl lg:text-6xl font-black tracking-tight text-[#202622] leading-tight">
                    Smart Cargo Transit. <br class="hidden sm:inline">
                    <span class="text-[#4B7B9F]">Reliable, Verified & Fair Rates.</span>
                </h1>
                <p class="text-lg text-[#61736A] max-w-2xl leading-relaxed">
                    Connect directly with verified drivers and vehicle owners verified via NIDA & TRA, from Guta tricycles and Kirikuu pick-ups to Canter, Fuso, and Scania semi-trailers. Transparent per-kilometer rates with no guesswork.
                </p>

                <!-- Action CTA & Quick Info -->
                <div class="pt-2 flex flex-col sm:flex-row sm:items-center space-y-3 sm:space-y-0 sm:space-x-4">
                    <a href="/preview/phone" class="btn-cargoo px-8 py-4 rounded-xl font-bold text-base flex items-center justify-center space-x-3 shadow-md">
                        <span>Launch App Preview</span>
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/></svg>
                    </a>
                    <a href="#vehicles" class="px-6 py-4 rounded-xl font-bold text-base text-[#202622] bg-white border border-[#CAD4CC] hover:bg-white/80 transition flex items-center justify-center space-x-2">
                        <span>Explore Vehicle Fleet</span>
                    </a>
                </div>

                <!-- Trust Badges -->
                <div class="pt-8 border-t border-[#CAD4CC]/60 grid grid-cols-3 gap-4 text-left">
                    <div>
                        <div class="text-2xl font-black text-[#202622]">100%</div>
                        <div class="text-xs text-[#61736A] font-semibold">Verified Drivers (NIDA)</div>
                    </div>
                    <div>
                        <div class="text-2xl font-black text-[#202622]">Cash</div>
                        <div class="text-xs text-[#61736A] font-semibold">Pay on Delivery</div>
                    </div>
                    <div>
                        <div class="text-2xl font-black text-[#202622]">PIN</div>
                        <div class="text-xs text-[#61736A] font-semibold">Delivery PIN & POD Protection</div>
                    </div>
                </div>
            </div>

            <!-- Interactive Vehicle Fleet Visual -->
            <div class="lg:col-span-5 bg-white border border-[#CAD4CC] rounded-3xl p-6 sm:p-8 shadow-sm">
                <div class="flex items-center justify-between pb-6 border-b border-[#CAD4CC]/50">
                    <div>
                        <h2 class="text-lg font-black text-[#202622]">Cargo Vehicle Categories</h2>
                        <p class="text-xs text-[#61736A]">Choose a vehicle suited to your load weight and size</p>
                    </div>
                    <span class="px-2.5 py-1 text-xs font-bold rounded-lg bg-[#E5EEF5] text-[#4B7B9F]">Dar es Salaam</span>
                </div>

                <div class="mt-6 space-y-3" id="vehicles">
                    <!-- Guta -->
                    <div class="p-3.5 rounded-2xl border border-[#CAD4CC]/70 hover:border-[#4B7B9F] bg-[#F2F5F1]/30 transition flex items-center justify-between cursor-pointer">
                        <div class="flex items-center space-x-3.5">
                            <div class="w-12 h-12 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center shadow-sm border border-[#CAD4CC]/40">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
                            </div>
                            <div>
                                <h3 class="text-sm font-bold text-[#202622]">Guta Cargo (3-Wheeler)</h3>
                                <p class="text-xs text-[#61736A]">Up to 500 kg • Small parcels & light cargo</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-[#4B7B9F]">from TZS 5,000</span>
                    </div>

                    <!-- Pickup / Kirikuu -->
                    <div class="p-3.5 rounded-2xl border-2 border-[#4B7B9F] bg-[#E5EEF5]/40 transition flex items-center justify-between cursor-pointer">
                        <div class="flex items-center space-x-3.5">
                            <div class="w-12 h-12 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center shadow-sm border border-[#CAD4CC]/40">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17a2 2 0 11-4 0 2 2 0 014 0zM19 17a2 2 0 11-4 0 2 2 0 014 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0"/></svg>
                            </div>
                            <div>
                                <div class="flex items-center space-x-2">
                                    <h3 class="text-sm font-bold text-[#202622]">Kirikuu Pick-up</h3>
                                    <span class="px-1.5 py-0.5 text-[10px] font-bold rounded bg-[#4B7B9F] text-white">Popular</span>
                                </div>
                                <p class="text-xs text-[#61736A]">Up to 1.2 Ton • Furniture, home & business loads</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-[#4B7B9F]">from TZS 12,000</span>
                    </div>

                    <!-- Canter -->
                    <div class="p-3.5 rounded-2xl border border-[#CAD4CC]/70 hover:border-[#4B7B9F] bg-[#F2F5F1]/30 transition flex items-center justify-between cursor-pointer">
                        <div class="flex items-center space-x-3.5">
                            <div class="w-12 h-12 rounded-xl bg-indigo-50 text-indigo-700 flex items-center justify-center shadow-sm border border-[#CAD4CC]/40">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"/></svg>
                            </div>
                            <div>
                                <h3 class="text-sm font-bold text-[#202622]">Canter Truck</h3>
                                <p class="text-xs text-[#61736A]">Up to 3.5 Ton • Store stock & wholesale cargo</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-[#4B7B9F]">from TZS 28,000</span>
                    </div>

                    <!-- Fuso -->
                    <div class="p-3.5 rounded-2xl border border-[#CAD4CC]/70 hover:border-[#4B7B9F] bg-[#F2F5F1]/30 transition flex items-center justify-between cursor-pointer">
                        <div class="flex items-center space-x-3.5">
                            <div class="w-12 h-12 rounded-xl bg-orange-50 text-orange-700 flex items-center justify-center shadow-sm border border-[#CAD4CC]/40">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
                            </div>
                            <div>
                                <h3 class="text-sm font-bold text-[#202622]">Fuso Fighter</h3>
                                <p class="text-xs text-[#61736A]">Up to 7.5 Ton • Construction & heavy commercial haul</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-[#4B7B9F]">from TZS 65,000</span>
                    </div>

                    <!-- Scania / Semi-Trailer -->
                    <div class="p-3.5 rounded-2xl border border-[#CAD4CC]/70 hover:border-[#4B7B9F] bg-[#F2F5F1]/30 transition flex items-center justify-between cursor-pointer">
                        <div class="flex items-center space-x-3.5">
                            <div class="w-12 h-12 rounded-xl bg-red-50 text-red-700 flex items-center justify-center shadow-sm border border-[#CAD4CC]/40">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
                            </div>
                            <div>
                                <h3 class="text-sm font-bold text-[#202622]">Scania Semi-Trailer</h3>
                                <p class="text-xs text-[#61736A]">Up to 28 Ton • Port containers & inter-regional freight</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-[#4B7B9F]">from TZS 160,000</span>
                    </div>
                </div>

                <div class="mt-6 pt-4 border-t border-[#CAD4CC]/50 text-center">
                    <a href="/preview/phone" class="text-xs font-bold text-[#4B7B9F] hover:underline flex items-center justify-center space-x-1">
                        <span>Open interactive vehicle booking screen</span>
                        <span>→</span>
                    </a>
                </div>
            </div>
        </section>

        <!-- How It Works Section -->
        <section id="how-it-works" class="border-t border-[#CAD4CC]/60 bg-white/70 py-16">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div class="text-center max-w-2xl mx-auto">
                    <h2 class="text-3xl font-black text-[#202622]">How CARGOO Works</h2>
                    <p class="mt-2 text-sm text-[#61736A]">3 simple steps to transport your goods reliably across Tanzania</p>
                </div>

                <div class="mt-12 grid md:grid-cols-3 gap-8">
                    <div class="p-6 rounded-2xl bg-[#F2F5F1] border border-[#CAD4CC]/80">
                        <div class="w-10 h-10 rounded-xl bg-[#4B7B9F] text-white flex items-center justify-center font-black mb-4">1</div>
                        <h3 class="text-base font-bold text-[#202622]">Select Vehicle & Review Rate</h3>
                        <p class="mt-2 text-sm text-[#61736A] leading-relaxed">
                            Specify your pickup and dropoff street addresses. Select the vehicle category matching your load weight and view transparent rates immediately.
                        </p>
                    </div>

                    <div class="p-6 rounded-2xl bg-[#F2F5F1] border border-[#CAD4CC]/80">
                        <div class="w-10 h-10 rounded-xl bg-[#4B7B9F] text-white flex items-center justify-center font-black mb-4">2</div>
                        <h3 class="text-base font-bold text-[#202622]">Driver Dispatches & Loads</h3>
                        <p class="mt-2 text-sm text-[#61736A] leading-relaxed">
                            A verified local driver confirms your request, navigates directly to your pickup point, and safely loads your cargo into the vehicle.
                        </p>
                    </div>

                    <div class="p-6 rounded-2xl bg-[#F2F5F1] border border-[#CAD4CC]/80">
                        <div class="w-10 h-10 rounded-xl bg-[#4B7B9F] text-white flex items-center justify-center font-black mb-4">3</div>
                        <h3 class="text-base font-bold text-[#202622]">Deliver, Confirm PIN & Pay</h3>
                        <p class="mt-2 text-sm text-[#61736A] leading-relaxed">
                            Upon safe arrival at your destination, provide the digital Delivery PIN to the driver for verification, and complete payment smoothly with cash.
                        </p>
                    </div>
                </div>
            </div>
        </section>
    </main>

    <!-- Footer -->
    <footer class="border-t border-[#CAD4CC]/60 bg-[#F2F5F1] py-8 text-center text-xs text-[#61736A]">
        <div class="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between space-y-4 sm:space-y-0">
            <div class="flex items-center space-x-2">
                <span class="font-black text-[#202622]">CARGOO</span>
                <span>— Every Load. Every Journey.</span>
            </div>
            <div>
                <span>© 2026 CARGOO Technology. All rights reserved. Dar es Salaam, Tanzania.</span>
            </div>
        </div>
    </footer>

</body>
</html>
