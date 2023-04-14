
 ;; typically this kind of contract requires an oracle that relays a jobID valid on the testnet so the contract can retrieve 
 ;; the current gold price from commodities-API.com and provides a function for other contracts to retrieve the current price
 ;; get address is the url + api key - here is mine: https://commodities-api.com/api/latest?access_key=ho90ir8l3777dymv9s6vzblbt5p34udvu3bqub662168au23b963x0gzq7kg
 ;; the JSON query for gold is x.data.rates.GOLD & Oil would be x.data.rates.BRENTOIL ; they don't list BTC but there are other resources for it 

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
