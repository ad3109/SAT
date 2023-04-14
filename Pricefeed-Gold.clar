
 ;; typically this kind of contract requires an oracle that relays a jobID valid on the testnet so the contract can retrieve 
 ;; the current gold price from commodities-API.com and provides a function for other contracts to retrieve the current price

(define-public (get-gold-price)
  (ok (http-client.request
       "https://commodities-api.com/api/v1/markets/quotes?symbol=XAUUSD"
       '(("X-COMMODITIES-API-KEY" . "<your-api-key>"))
       "")))
 ;; seperating the API key from the URL doesn't work - it needs to be on one line in SOL
 
(define-public (parse-gold-price response)
  (let ((response-json (json->clarity (http-response.body response))))
    (let ((price (get response-json 'data 0 'lastPrice)))
      (if (none? price)
          (err "Could not parse gold price from response.")
          (ok (price))))))

(define-public (gold-price)
  (let ((response (get-gold-price)))
    (if (ok? response)
        (parse-gold-price (unwrap response))
        (err (unwrap-err response)))))

;; The get-gold-price function sends an HTTP request to the commodities-API.com API to retrieve the current gold price, using an API key 
;; specified in the request headers. The parse-gold-price function extracts the gold price from the API response and returns it as a uint128.
