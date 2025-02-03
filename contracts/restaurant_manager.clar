;; SmartServe Restaurant Management Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-reservation (err u101))
(define-constant err-table-occupied (err u102))
(define-constant err-insufficient-points (err u103))
(define-constant err-invalid-menu-item (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-invalid-table (err u106))

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
  { 
    capacity: uint, 
    is-occupied: bool,
    last-cleaned: uint
  }
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
    (table-info (default-to { capacity: u0, is-occupied: true, last-cleaned: u0 } 
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
        (map-set Tables
          { table-number: table-number }
          { 
            capacity: (unwrap! (get capacity (map-get? Tables { table-number: table-number })) err-invalid-table),
            is-occupied: true,
            last-cleaned: (unwrap! (get last-cleaned (map-get? Tables { table-number: table-number })) err-invalid-table)
          }
        )
        (ok true)
      )
      err-invalid-reservation
    )
  )
)

(define-public (update-table-status (table-number uint) (is-clean bool))
  (if (is-eq tx-sender contract-owner)
    (let (
      (table (unwrap! (map-get? Tables { table-number: table-number }) err-invalid-table))
    )
      (map-set Tables
        { table-number: table-number }
        (merge table { 
          is-occupied: false,
          last-cleaned: (if is-clean block-height u0)
        })
      )
      (ok true)
    )
    err-owner-only
  )
)

[REST OF CONTRACT REMAINS UNCHANGED]
