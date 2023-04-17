
;; title: SATVault01_chatGPT
;; version:
;; summary:
;; description:

;; traits

;; token definitions

;; constants

;; data vars

;; data maps

;; public functions

;; read only functions

;; private functions

;; define the contract variables
(define-contract Vault ()
    ((priceFeed AnyAPIPriceFeed)
    (stablecoin Stablecoin)
    (COLLATERALIZATION_RATIO uint256 (constant 150))
    (LIQUIDATION_THRESHOLD uint256 (constant 120))
    (balances (map address uint256))
    (isCollateral (map address bool)))

    ;; (define-public priceFeed any-api-price-feed)
    ;; (define-public stablecoin stablecoin)

    ;; (define-public COLLATERALIZATION_RATIO 150)
    ;; (define-public LIQUIDATION_THRESHOLD 120)

    ;; (define balances (tuple))
    ;; (define isCollateral (tuple))

    ;; define the constructor
    (init (_priceFeed (buff 20)) (_stablecoin (buff 20))
        (begin
            (var priceFeedAddress (from-buff _priceFeed))
            (var stablecoinAddress (from-buff _stablecoin))
            (map-set isCollateral 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 true)
            (map-set isCollateral 0x45804880De22913dAFE09f4980848ECE6EcbAf78 true)
            (var priceFeedContract (clarity-call priceFeedAddress (function AnyAPIPriceFeed)))
            (var stablecoinContract (clarity-call stablecoinAddress (function Stablecoin)))
            (begin
                (set priceFeed priceFeedContract)
                (set stablecoin stablecoinContract)
            )
        )
    )

    (define-public (set-price-feed pf)
        (begin
            (require (check-sender? (address this)))
            (set! priceFeed pf)
        )
    ) ; setter for priceFeed

    (define-public (set-stablecoin sc)
        (begin
            (require (check-sender? (address this)))
            (set! stablecoin sc)
        )
    ) ; setter for stablecoin


    ;; Lock Function
    ;; Allows users to lock their collateral and receive the equivalent amount of stablecoin (DAI) 
    ;; based on the collateralization ratio. The function checks whether the specified collateral 
    ;; is valid and has a price available. It then calculates the value of the collateral and ensures 
    ;; that there is enough stablecoin available in the contract. If everything checks out, the user's 
    ;; balance is updated and they receive their stablecoin.

    (define-public (lock (_collateral (buff 20)) (_amount uint256))
        (begin
            (require (isTrue (map-get isCollateral (from-buff _collateral))) "Invalid collateral")
            (require (> (clarity-call priceFeed (function getPrice) (from-buff _collateral)) 0) "Price not available")
            (var collateralValue (* (clarity-call priceFeed (function getPrice) (from-buff _collateral)) _amount (/ 1e18)))
            (var daiAmount (* collateralValue (/ COLLATERALIZATION_RATIO 100)))
            (require (>= (clarity-call stablecoin (function balanceOf) (address this)) daiAmount) "Not enough Dai available")
            (map-set balances (msg-sender) (+ (map-get balances (msg-sender)) _amount))
            (require (clarity-call stablecoin (function transfer) (msg-sender) daiAmount) "Failed to transfer Dai")
        )
    )

    ;; (define-public (lock (_collateral (buff 20)) (_amount uint256))
    ;;     (begin
    ;;         (require (isTrue (map-get isCollateral (from-buff _collateral))) "Invalid collateral")
    ;;         (require (> (clarity-call priceFeed (function getPrice) (from-buff _collateral)) 0) "Price not available")
    ;;         (let ((collateralValue (* (clarity-call priceFeed (function getPrice) (from-buff _collateral)) _amount (/ 1e18)))
    ;;             (daiAmount (* collateralValue (/ COLLATERALIZATION_RATIO 100))))
    ;;             (require (>= (clarity-call stablecoin (function balanceOf) (address this)) daiAmount) "Not enough Dai available")
    ;;             (map-set balances (msg-sender) (+ (map-get balances (msg-sender)) _amount))
    ;;             (require (clarity-call stablecoin (function transfer) (msg-sender) daiAmount) "Failed to transfer Dai")
    ;;         )
    ;;     )
    ;; )


    ;; Unlock Function
    ;; Allows users to unlock their collateral by sending back the equivalent amount of stablecoin 
    ;; to the contract. The function checks whether the specified collateral is valid and that the 
    ;; user has enough balance. If everything checks out, the user's balance is updated and the stablecoin 
    ;; is transferred back to the contract.
    (define-public (unlock (_collateral (buff 20)) (_amount uint256))
        (begin
            (require (isTrue (map-get isCollateral (from-buff _collateral))) "Invalid collateral")
            (require (>= (map-get balances (msg-sender)) _amount) "Insufficient collateral balance")
            (map-set balances (msg-sender) (- (map-get balances (msg-sender)) _amount))
            (require (clarity-call stablecoin (function transferFrom) (msg-sender) (address this) _amount) "Failed to transfer Dai")
        )
    )

    ;; (define-public (unlock (_collateral (buff 20)) (_amount uint256))
    ;;     (begin
    ;;         (require (is-true (map-get isCollateral (buff->principal _collateral))) "Invalid collateral")
    ;;         (require (>= (map-get balances (get-block-issuer)) _amount) "Insufficient collateral balance")
    ;;         (map-update balances (get-block-issuer) (- _amount))
    ;;         (require (ok? (clarity-call stablecoin (function transferFrom) (get-block-issuer) (address this) _amount)) "Failed to transfer Dai")
    ;;     )
    ;; )


    ;; Liquidate function
    ;; Allows anyone to liquidate an account if their collateralization ratio falls below the  
    ;; liquidation threshold. The function checks whether the account's collateral value is below the  
    ;; liquidation threshold and burns the equivalent amount of stablecoin based on the collateralization ratio.
    (define-public (liquidate (_account address))
        (begin
            (var collateralValue (getCollateralValue _account))
            (require (< collateralValue (* (clarity-call stablecoin (function balanceOf) (address this)) (/ LIQUIDATION_THRESHOLD 100))) "Collateral above liquidation threshold")
            (map-set balances _account 0)
            (clarity-call stablecoin (function burn) (* collateralValue (/ 100 COLLATERALIZATION_RATIO)))
        )
    )

    ;; (define-public (liquidate (_account (buff 20)))
    ;;     (let ((collateralValue (getCollateralValue _account)))
    ;;         (require (< collateralValue (div (mul (stablecoin-balanceOf (address this)) LIQUIDATION_THRESHOLD) 100)) "Collateral above liquidation threshold")
    ;;         (balances-put _account u0)
    ;;         (stablecoin-burn (div (mul collateralValue 100) COLLATERALIZATION_RATIO))
    ;;     )
    ;; )


    ;; define the getCollateralValue function
    ;; Calculates the total value of a user's collateral by looping through the accepted collateral 
    ;; types and checking if the user has a balance for that type. If the user has a balance, the function 
    ;; calculates the value of the collateral based on the price feed and adds it to the total value
    (define-public (getCollateralValue (_account (buff 20)))
        (let ((totalValue u0))
            (for ((i 0) (i< 2) (add i 1))
                (let ((collateral (if (eq i 0) (buff 20 "2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599") (buff 20 "45804880De22913dAFE09f4980848ECE6EcbAf78")))) ; BTC and PAXG
                    (if (and (> (balances-get _account) u0) (isCollateral-get collateral))
                        (let ((collateralValue (div (mul (priceFeed-getPrice collateral) (balances-get _account)) u1e18)))
                            (set totalValue (add totalValue collateralValue)))
                    )
                )
            )
            totalValue
        )
    )

)

