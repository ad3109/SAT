;; SATVault ver01 - this a a vault contract accepting any crypto currency as collateral and mints SAT at time of mint. 
;; 98% of the collateral automatically purchases an equal balance of bitcoin and paxg, and sends that purchase and the 
;; remaining 2% to an admin wallet named SATAdmin

(define-miner-fee 0) ;; set miner fee to 0

(define-data-var SATAdmin (buff 20)) ;; admin address

;; Collateral data struct
(define-data-var Collateral (struct
  (value uint) ;; value of collateral
  (currency (buff 20)) ;; currency of collateral
))

;; Vault data struct
(define-data-var SATVault (struct
  (stablecoin uint) ;; total amount of stablecoin minted
  (collateral-map (map (buff 20) Collateral)) ;; map of collateral
))

;; BTC and PAXG tokens
(define BTC (buff 20 "Bitcoin"))
(define PAXG (buff 20 "Pax Gold"))

;; Aggregator interfaces for BTC and PAXG
(define BTCFeed (contract-read "BTCFeed"))
(define PAXGFeed (contract-read "PAXGFeed"))

;; Pricefeed interface for stablecoin
(define SATPriceFeed (contract-read "SATPriceFeed"))

;; Function to calculate purchase amounts
(define (calculate-purchase-amounts amount)
  (let ((half-amount (div amount 2)))
    (list half-amount half-amount)
  )
)

(define-public (mint-stablecoin collateral-value collateral-currency)
  (let* ((price-feed (call SATPriceFeed "get-price")) ;; get the price of the stablecoin
         (stablecoin-price (at 'price price-feed))
         (stablecoin-amount (div collateral-value stablecoin-price)) ;; calculate amount of stablecoin to mint
         (btc-paxg-amounts (calculate-purchase-amounts (mul collateral-value 98))) ;; calculate amounts of BTC and PAXG to purchase
         (btc-amount (list-ref btc-paxg-amounts 0))
         (paxg-amount (list-ref btc-paxg-amounts 1))
         (admin-fee (mul collateral-value 2)) ;; calculate admin fee
         (collateral (Collateral (value collateral-value) (currency collateral-currency)))
         (vault (get SATVault))
         (updated-collateral-map (set-map (collateral-currency) collateral (at 'collateral-map vault))))
    (begin
      (transfer collateral-currency SATAdmin admin-fee) ;; transfer admin fee to admin wallet
      (transfer-currency BTC BTCFeed btc-amount) ;; purchase BTC
      (transfer-currency PAXG PAXGFeed paxg-amount) ;; purchase PAXG
      (update SATVault (SATVault (add stablecoin-amount (at 'stablecoin vault)) updated-collateral-map)) ;; update vault with new stablecoin amount and collateral map
      stablecoin-amount
    )
  )
)

;; To mint SAT users call the mint-stablecoin function and pass in the value and currency of their collateral. The function will calculate the 
;; amount of stablecoin to mint based on the current price of the stablecoin, purchase an equal balance of Bitcoin and PAXG with 98% of the 
;; collateral value, send the remaining 2% as an admin fee to the SATAdmin wallet
