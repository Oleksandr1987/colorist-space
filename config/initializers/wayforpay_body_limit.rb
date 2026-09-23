require Rails.root.join("lib/wayforpay_body_limit").to_s
Rails.application.config.middleware.insert_before 0, WayforpayBodyLimit
