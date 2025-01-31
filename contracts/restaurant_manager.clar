;; SmartServe Restaurant Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-reservation (err u101))
(define-constant err-table-occupied (err u102))
(define-constant err-insufficient-points (err u103))
(define-constant err-invalid-menu-item (err u104))
(define-constant err-invalid-amount (err u105))

;; Data Variables
(define-data-var loyalty-rate uint u10) ;; Points per STX spent
(define-data-var points-redemption-rate uint u100) ;; Points needed per STX discount

(define-map Reservations
  { reservation-id: uint }
  {
    customer: principal,
    table-number: uint,
    time-slot: uint,
    guests: uint,
    status: (string-ascii 20)
  }
)

(define-map Orders 
  { order-id: uint }
  {
    customer: principal,
    items: (list 10 uint),
    total-amount: uint,
    points-used: uint,
    final-amount: uint,
    status: (string-ascii 20)
  }
)

(define-map CustomerPoints
  { customer: principal }
  { points: uint }
)

(define-map Tables
  { table-number: uint }
  { capacity: uint, is-occupied: bool }
)

(define-map MenuItem
  { item-id: uint }
  {
    name: (string-ascii 50),
    price: uint,
    category: (string-ascii 20),
    available: bool
  }
)

;; Private Functions
(define-private (is-valid-reservation (table-number uint) (time-slot uint))
  (let (
    (table-info (default-to { capacity: u0, is-occupied: true } 
      (map-get? Tables { table-number: table-number })))
  )
    (and 
      (not (get is-occupied table-info))
      (> (get capacity table-info) u0)
    )
  )
)

(define-private (calculate-final-amount (total uint) (points-to-use uint))
  (let (
    (discount (/ points-to-use (var-get points-redemption-rate)))
  )
    (if (>= total discount)
      (- total discount)
      u0)
  )
)

;; Public Functions
(define-public (make-reservation (reservation-id uint) (table-number uint) (time-slot uint) (guests uint))
  (let (
    (is-valid (is-valid-reservation table-number time-slot))
  )
    (if is-valid
      (begin
        (map-set Reservations
          { reservation-id: reservation-id }
          {
            customer: tx-sender,
            table-number: table-number,
            time-slot: time-slot,
            guests: guests,
            status: "confirmed"
          }
        )
        (ok true)
      )
      err-invalid-reservation
    )
  )
)

(define-public (place-order (order-id uint) (items (list 10 uint)) (total-amount uint) (points-to-use uint))
  (let (
    (customer-points (get points (default-to { points: u0 } (map-get? CustomerPoints { customer: tx-sender }))))
    (final-amount (calculate-final-amount total-amount points-to-use))
  )
    (if (>= customer-points points-to-use)
      (begin
        (map-set CustomerPoints
          { customer: tx-sender }
          { points: (- customer-points points-to-use) }
        )
        (map-set Orders
          { order-id: order-id }
          {
            customer: tx-sender,
            items: items,
            total-amount: total-amount,
            points-used: points-to-use,
            final-amount: final-amount,
            status: "pending"
          }
        )
        (ok true)
      )
      err-insufficient-points
    )
  )
)

(define-public (add-loyalty-points (customer principal) (amount uint))
  (let (
    (current-points (default-to { points: u0 } 
      (map-get? CustomerPoints { customer: customer })))
    (points-to-add (* amount (var-get loyalty-rate)))
  )
    (map-set CustomerPoints
      { customer: customer }
      { points: (+ (get points current-points) points-to-add) }
    )
    (ok true)
  )
)

(define-public (add-menu-item (item-id uint) (name (string-ascii 50)) (price uint) (category (string-ascii 20)))
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set MenuItem
        { item-id: item-id }
        {
          name: name,
          price: price,
          category: category,
          available: true
        }
      )
      (ok true)
    )
    err-owner-only
  )
)

(define-public (update-menu-item-availability (item-id uint) (available bool))
  (if (is-eq tx-sender contract-owner)
    (let (
      (item (unwrap! (map-get? MenuItem { item-id: item-id }) err-invalid-menu-item))
    )
      (map-set MenuItem
        { item-id: item-id }
        (merge item { available: available })
      )
      (ok true)
    )
    err-owner-only
  )
)

;; Read-only functions
(define-read-only (get-reservation-details (reservation-id uint))
  (map-get? Reservations { reservation-id: reservation-id })
)

(define-read-only (get-order-details (order-id uint))
  (map-get? Orders { order-id: order-id })
)

(define-read-only (get-customer-points (customer principal))
  (default-to { points: u0 } 
    (map-get? CustomerPoints { customer: customer }))
)

(define-read-only (get-menu-item (item-id uint))
  (map-get? MenuItem { item-id: item-id })
)
