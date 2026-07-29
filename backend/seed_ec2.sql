DO $$ 
DECLARE
    -- Customer UUIDs
    cust1_user_id UUID := gen_random_uuid();
    cust1_id UUID := gen_random_uuid();
    cust1_addr_id UUID := gen_random_uuid();

    cust2_user_id UUID := gen_random_uuid();
    cust2_id UUID := gen_random_uuid();
    cust2_addr_id UUID := gen_random_uuid();

    cust3_user_id UUID := gen_random_uuid();
    cust3_id UUID := gen_random_uuid();
    cust3_addr_id UUID := gen_random_uuid();

    -- Delivery Partner UUIDs
    dp1_user_id UUID := gen_random_uuid();
    dp1_id UUID := gen_random_uuid();

    dp2_user_id UUID := gen_random_uuid();
    dp2_id UUID := gen_random_uuid();

    -- Existing product and fruit UUIDs (we will fetch one dynamically)
    random_fruit_id UUID;
    random_product_id UUID;
BEGIN
    -- 1. Create Customers
    INSERT INTO users (id, phone, full_name, password_hash, role, status, is_verified, created_at, updated_at) 
    VALUES (cust1_user_id, '9999999901', 'Arun Kumar', 'mock_hash', 'customer', 'active', true, now(), now());
    INSERT INTO customers (id, user_id, customer_code, created_at, updated_at) VALUES (cust1_id, cust1_user_id, 'CUST001', now(), now());
    INSERT INTO addresses (id, user_id, address_type, address_line1, city, state, pincode, latitude, longitude, is_default, created_at, updated_at) 
    VALUES (cust1_addr_id, cust1_user_id, 'home', '123 Main St', 'Chennai', 'Tamil Nadu', '600001', 13.0827, 80.2707, true, now(), now());

    INSERT INTO users (id, phone, full_name, password_hash, role, status, is_verified, created_at, updated_at) 
    VALUES (cust2_user_id, '9999999902', 'Priya', 'mock_hash', 'customer', 'active', true, now(), now());
    INSERT INTO customers (id, user_id, customer_code, created_at, updated_at) VALUES (cust2_id, cust2_user_id, 'CUST002', now(), now());
    INSERT INTO addresses (id, user_id, address_type, address_line1, city, state, pincode, latitude, longitude, is_default, created_at, updated_at) 
    VALUES (cust2_addr_id, cust2_user_id, 'home', '456 Cross St', 'Chennai', 'Tamil Nadu', '600002', 13.0827, 80.2707, true, now(), now());

    INSERT INTO users (id, phone, full_name, password_hash, role, status, is_verified, created_at, updated_at) 
    VALUES (cust3_user_id, '9999999903', 'Karthik', 'mock_hash', 'customer', 'active', true, now(), now());
    INSERT INTO customers (id, user_id, customer_code, created_at, updated_at) VALUES (cust3_id, cust3_user_id, 'CUST003', now(), now());
    INSERT INTO addresses (id, user_id, address_type, address_line1, city, state, pincode, latitude, longitude, is_default, created_at, updated_at) 
    VALUES (cust3_addr_id, cust3_user_id, 'home', '789 East St', 'Chennai', 'Tamil Nadu', '600003', 13.0827, 80.2707, true, now(), now());

    -- 2. Create Delivery Partners
    INSERT INTO users (id, phone, full_name, password_hash, role, status, is_verified, created_at, updated_at) 
    VALUES (dp1_user_id, '8888888801', 'Dinesh', 'mock_hash', 'delivery_partner', 'active', true, now(), now());
    INSERT INTO delivery_partners (id, user_id, employee_code, vehicle_type, vehicle_number, is_available, created_at, updated_at) 
    VALUES (dp1_id, dp1_user_id, 'DP001', 'motorcycle', 'TN01AB1234', true, now(), now());

    INSERT INTO users (id, phone, full_name, password_hash, role, status, is_verified, created_at, updated_at) 
    VALUES (dp2_user_id, '8888888802', 'Prakash', 'mock_hash', 'delivery_partner', 'active', true, now(), now());
    INSERT INTO delivery_partners (id, user_id, employee_code, vehicle_type, vehicle_number, is_available, created_at, updated_at) 
    VALUES (dp2_id, dp2_user_id, 'DP002', 'motorcycle', 'TN01CD5678', true, now(), now());

    -- Get a random fruit and product if they exist
    SELECT id INTO random_fruit_id FROM fruits LIMIT 1;
    SELECT id INTO random_product_id FROM products LIMIT 1;

    -- 3. Create Orders (Mix of Subscriptions and Fruit Orders)
    FOR i IN 1..8 LOOP
        -- Insert Fruit Orders
        IF random_fruit_id IS NOT NULL THEN
            DECLARE
                new_order_id UUID := gen_random_uuid();
            BEGIN
                INSERT INTO fruit_orders (id, customer_id, order_number, order_status, total_amount, payment_status, address_id, created_at, updated_at)
                VALUES (
                    new_order_id, 
                    CASE WHEN i % 3 = 0 THEN cust1_id WHEN i % 3 = 1 THEN cust2_id ELSE cust3_id END, 
                    'FO-' || substring(new_order_id::text from 1 for 8),
                    'pending', 250.00, 'success', 
                    CASE WHEN i % 3 = 0 THEN cust1_addr_id WHEN i % 3 = 1 THEN cust2_addr_id ELSE cust3_addr_id END,
                    now() - (i || ' days')::interval, now()
                );
                
                INSERT INTO fruit_order_items (id, order_id, fruit_id, quantity_kg, price_per_kg, subtotal, created_at, updated_at)
                VALUES (gen_random_uuid(), new_order_id, random_fruit_id, 2.0, 125.00, 250.00, now(), now());
            END;
        END IF;

        -- Insert Subscriptions
        IF random_product_id IS NOT NULL THEN
            DECLARE
                new_sub_id UUID := gen_random_uuid();
            BEGIN
                INSERT INTO subscriptions (id, customer_id, product_id, plan_type, status, total_deliveries, address_id, start_date, expected_end_date, preferred_delivery_time, total_amount, package_price, delivery_partner_id, created_at, updated_at)
                VALUES (
                    new_sub_id, 
                    CASE WHEN i % 3 = 0 THEN cust2_id WHEN i % 3 = 1 THEN cust3_id ELSE cust1_id END, 
                    random_product_id, 'weekly', 'active', 7, 
                    CASE WHEN i % 3 = 0 THEN cust2_addr_id WHEN i % 3 = 1 THEN cust3_addr_id ELSE cust1_addr_id END,
                    now(), now() + interval '7 days', 'morning', 1500.00, 1500.00,
                    CASE WHEN i % 2 = 0 THEN dp2_id ELSE dp1_id END,
                    now() - (i || ' days')::interval, now()
                );

                INSERT INTO subscription_items (id, subscription_id, product_id, quantity, package_price, created_at, updated_at)
                VALUES (gen_random_uuid(), new_sub_id, random_product_id, 1, 1500.00, now(), now());
            END;
        END IF;
    END LOOP;
END $$;
