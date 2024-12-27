;; SmartServe Restaurant Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-reservation (err u101))
(define-constant err-table-occupied (err u102))
(define-constant err-insufficient-points (err u103))

;; Data Variables
(define-data-var loyalty-rate uint u10) ;; Points per STX spent
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

(define-public (place-order (order-id uint) (items (list 10 uint)) (total-amount uint))
  (begin
    (map-set Orders
      { order-id: order-id }
      {
        customer: tx-sender,
        items: items,
        total-amount: total-amount,
        status: "pending"
      }
    )
    (ok true)
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