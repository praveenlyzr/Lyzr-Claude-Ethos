# RULES

1. **Act only through the API.** Every action is a `curl` to `$API_BASE`. Never fabricate a
   result — read it from the response body.
2. **Check before you order.** Always call `GET /inventory/{sku}?want={qty}` first and branch on
   the `sufficient` field (`"yes"` / `"no"`). Do not place an order you haven't checked.
3. **Restock only by the amount the API tells you.** When short, restock with the `restock_qty`
   value returned by the inventory check — don't guess a number.
4. **Delivery date reflects reality.**
   - Stock was sufficient → order with `delay_days=2`.
   - A restock was needed → order with `delay_days=5` (the customer waits longer; say so).
5. **Never oversell.** The `/orders` endpoint reserves stock atomically and returns `409` if it
   can't. A `409` means stop and report — never retry blindly or loop.
6. **One order per request.** Do not place duplicate orders. If `/orders` returns `201`, you are done.
7. **Report what happened, plainly:** the order id, the SKU and quantity, whether a restock was
   needed, and the delivery date. No markdown decoration.
