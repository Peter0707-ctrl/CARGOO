<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CARGOO Driver Portal • Live Dispatch</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #4B7B9F;
            --primary-dark: #2F5573;
            --primary-light: #EBF1F5;
            --bg: #F4F6F4;
            --card-bg: #FFFFFF;
            --text-main: #0F172A;
            --text-muted: #64748B;
            --border: #CAD4CC;
            --success: #10B981;
            --warning: #F59E0B;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Plus Jakarta Sans', sans-serif;
        }

        body {
            background-color: var(--bg);
            color: var(--text-main);
            min-height: 100vh;
            padding-bottom: 60px;
        }

        .header {
            background: #FFFFFF;
            border-bottom: 1px solid var(--border);
            padding: 16px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 50;
            box-shadow: 0 2px 8px rgba(0,0,0,0.03);
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .brand-logo {
            background: var(--primary);
            color: white;
            font-weight: 900;
            padding: 6px 12px;
            border-radius: 12px;
            font-size: 14px;
            letter-spacing: 1px;
        }

        .brand-title {
            font-size: 18px;
            font-weight: 900;
            color: var(--text-main);
        }

        .driver-badge {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 800;
            background: #ECFDF5;
            color: #065F46;
            border: 1px solid #A7F3D0;
        }

        .pulse-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--success);
            box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
            animation: pulse 1.6s infinite;
        }

        @keyframes pulse {
            0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
            70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
            100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
        }

        .container {
            max-width: 900px;
            margin: 24px auto;
            padding: 0 16px;
        }

        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            margin-bottom: 18px;
        }

        .section-title {
            font-size: 20px;
            font-weight: 900;
        }

        .section-subtitle {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        .orders-feed {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }

        .order-card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 20px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.03);
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .order-card:hover {
            box-shadow: 0 6px 18px rgba(75, 123, 159, 0.1);
        }

        .order-top {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            border-bottom: 1px solid var(--bg);
            padding-bottom: 14px;
            margin-bottom: 14px;
        }

        .customer-info {
            display: flex;
            align-items: center;
            gap: 14px;
        }

        .customer-avatar {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background: var(--primary-light);
            border: 2px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            font-weight: 900;
            color: var(--primary);
            overflow: hidden;
        }

        .customer-avatar img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .customer-meta h4 {
            font-size: 15px;
            font-weight: 800;
            color: var(--text-main);
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .nida-tag {
            font-size: 10.5px;
            background: #E5EEF5;
            color: var(--primary-dark);
            padding: 2px 7px;
            border-radius: 6px;
            font-weight: 800;
        }

        .customer-meta p {
            font-size: 12.5px;
            color: var(--text-muted);
            font-weight: 600;
            margin-top: 2px;
        }

        .fare-badge {
            text-align: right;
        }

        .fare-amount {
            font-size: 18px;
            font-weight: 900;
            color: var(--primary-dark);
        }

        .vehicle-name {
            font-size: 12px;
            font-weight: 700;
            color: var(--text-muted);
        }

        .route-timeline {
            display: flex;
            gap: 12px;
            margin: 14px 0;
            background: #F8FAFC;
            padding: 14px;
            border-radius: 14px;
            border: 1px solid #E2E8F0;
        }

        .route-indicators {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding-top: 4px;
        }

        .dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
        }

        .dot.pickup { background: var(--primary); }
        .dot.dropoff { background: #DC2626; }

        .line {
            width: 2px;
            height: 32px;
            background: var(--border);
            margin: 4px 0;
        }

        .route-details {
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 14px;
        }

        .route-stop-title {
            font-size: 11px;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--text-muted);
        }

        .route-stop-address {
            font-size: 13.5px;
            font-weight: 700;
            color: var(--text-main);
        }

        .order-extra {
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
            margin: 12px 0;
            padding: 10px 14px;
            background: #FFFBEB;
            border: 1px solid #FDE68A;
            border-radius: 12px;
            font-size: 12px;
        }

        .extra-item {
            display: flex;
            align-items: center;
            gap: 6px;
            color: #92400E;
            font-weight: 600;
        }

        .actions-row {
            display: flex;
            gap: 10px;
            margin-top: 14px;
        }

        .btn {
            flex: 1;
            padding: 12px 16px;
            border-radius: 12px;
            font-size: 13px;
            font-weight: 800;
            text-align: center;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            border: none;
            transition: all 0.2s;
        }

        .btn-primary {
            background: var(--primary);
            color: white;
        }

        .btn-primary:hover {
            background: var(--primary-dark);
        }

        .btn-call {
            background: #ECFDF5;
            color: #065F46;
            border: 1px solid #A7F3D0;
        }

        .btn-call:hover {
            background: #D1FAE5;
        }

        .empty-state {
            background: white;
            border: 1px solid var(--border);
            border-radius: 20px;
            padding: 48px 24px;
            text-align: center;
        }

        .empty-icon {
            font-size: 40px;
            margin-bottom: 14px;
        }
    </style>
</head>
<body>

    <header class="header">
        <div class="brand">
            <span class="brand-logo">CARGOO</span>
            <span class="brand-title">Driver Dispatch Terminal</span>
        </div>
        <div class="driver-badge">
            <span class="status-pill">
                <span class="pulse-dot"></span> Online • Ready for Cargo
            </span>
        </div>
    </header>

    <main class="container">
        <div class="section-header">
            <div>
                <h2 class="section-title">Live Dispatched Cargo Requests</h2>
                <p class="section-subtitle">Real-time orders transmitted directly from customer app with full customer identity.</p>
            </div>
            <button onclick="fetchOrders()" class="btn btn-call" style="flex: none; padding: 8px 14px; font-size: 12px;">
                ↻ Refresh Live Feed
            </button>
        </div>

        <div id="ordersFeed" class="orders-feed">
            <div class="empty-state">
                <div class="empty-icon">⏳</div>
                <h3>Listening for Customer Bookings...</h3>
                <p style="color: var(--text-muted); font-size: 13px; margin-top: 6px;">
                    When a customer taps "Confirm CARGOO Booking" in their app, their profile picture, verified name, contact, route, and cargo payload will appear here automatically.
                </p>
            </div>
        </div>
    </main>

    <script>
        async function fetchOrders() {
            try {
                const res = await fetch('/api/v1/orders');
                const data = await res.json();
                const feed = document.getElementById('ordersFeed');

                if (!data.orders || data.orders.length === 0) {
                    feed.innerHTML = `
                        <div class="empty-state">
                            <div class="empty-icon">🚛</div>
                            <h3>Waiting for Next Cargo Request</h3>
                            <p style="color: var(--text-muted); font-size: 13px; margin-top: 6px;">
                                Ready to accept cargo shipments. Once a user books ("akibolt"), their full verified details appear right here.
                            </p>
                        </div>
                    `;
                    return;
                }

                feed.innerHTML = data.orders.map(order => {
                    const avatarHtml = order.customer_avatar && order.customer_avatar.startsWith('http')
                        ? `<img src="${order.customer_avatar}" alt="${order.customer_name}">`
                        : (order.customer_name ? order.customer_name.charAt(0).toUpperCase() : 'C');

                    const recipientInfo = order.recipient_name 
                        ? `<div class="extra-item"><span>📦</span> <strong>Dropoff Recipient:</strong> ${order.recipient_name} (${order.recipient_phone || 'Direct'})</div>`
                        : '';

                    const notesInfo = order.cargo_notes
                        ? `<div class="extra-item"><span>📝</span> <strong>Manifest Notes:</strong> ${order.cargo_notes}</div>`
                        : '';

                    return `
                        <div class="order-card" id="card-${order.trip_id}">
                            <div class="order-top">
                                <div class="customer-info">
                                    <div class="customer-avatar">${avatarHtml}</div>
                                    <div class="customer-meta">
                                        <h4>
                                            ${order.customer_name}
                                            <span class="nida-tag">✓ Verified NIDA</span>
                                        </h4>
                                        <p>Phone: ${order.customer_phone} • Ref: ${order.trip_id}</p>
                                    </div>
                                </div>
                                <div class="fare-badge">
                                    <div class="fare-amount">${order.fare_amount}</div>
                                    <div class="vehicle-name">${order.vehicle_type} (${order.driver_plate})</div>
                                </div>
                            </div>

                            <div class="route-timeline">
                                <div class="route-indicators">
                                    <div class="dot pickup"></div>
                                    <div class="line"></div>
                                    <div class="dot dropoff"></div>
                                </div>
                                <div class="route-details">
                                    <div>
                                        <div class="route-stop-title">Cargo Pickup Location (Sender: ${order.sender_name})</div>
                                        <div class="route-stop-address">${order.pickup_name}</div>
                                    </div>
                                    <div>
                                        <div class="route-stop-title">Cargo Dropoff Location</div>
                                        <div class="route-stop-address">${order.dropoff_name}</div>
                                    </div>
                                </div>
                            </div>

                            ${recipientInfo || notesInfo ? `
                                <div class="order-extra">
                                    ${recipientInfo}
                                    ${notesInfo}
                                </div>
                            ` : ''}

                            <div class="actions-row">
                                <a href="tel:${order.customer_phone}" class="btn btn-call">
                                    📞 Call Customer (${order.customer_name.split(' ')[0]})
                                </a>
                                <button onclick="acceptOrder('${order.trip_id}')" class="btn btn-primary">
                                    ✓ Accept & Navigate (${order.distance_km} km)
                                </button>
                            </div>
                        </div>
                    `;
                }).join('');
            } catch (err) {
                console.error("Orders feed error:", err);
            }
        }

        async function acceptOrder(tripId) {
            alert(`Order #${tripId} accepted! Navigation starting to customer pickup address.`);
        }

        // Auto poll every 4 seconds
        setInterval(fetchOrders, 4000);
        fetchOrders();
    </script>
</body>
</html>
