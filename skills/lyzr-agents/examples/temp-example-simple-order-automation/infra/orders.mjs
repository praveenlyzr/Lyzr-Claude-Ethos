// POST /orders {sku, qty, customer, delivery_date?} — atomically reserves stock and records the order.
// Returns 409 if stock is insufficient (so the caller knows to restock first). Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const INV = process.env.INVENTORY_TABLE;
const ORD = process.env.ORDERS_TABLE;

const parse = (e) => { try { return JSON.parse(e?.body || "{}"); } catch { return {}; } };
const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});
const isoPlusDays = (d) => new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);

export const handler = async (event) => {
  const b = parse(event);
  const sku = b.sku;
  const qty = Number(b.qty);
  const customer = b.customer || "anonymous";
  if (!sku || !Number.isFinite(qty) || qty <= 0) return resp(400, { error: "sku and positive qty required" });

  // Atomic, condition-checked decrement — never oversells.
  let remaining;
  try {
    const { Attributes } = await ddb.send(new UpdateCommand({
      TableName: INV,
      Key: { sku },
      UpdateExpression: "SET quantity = quantity - :q",
      ConditionExpression: "attribute_exists(sku) AND quantity >= :q",
      ExpressionAttributeValues: { ":q": qty },
      ReturnValues: "ALL_NEW",
    }));
    remaining = Number(Attributes.quantity);
  } catch (e) {
    if (e.name === "ConditionalCheckFailedException") {
      return resp(409, { error: "insufficient stock", sku, requested: qty });
    }
    throw e;
  }

  const order = {
    order_id: "ord_" + randomUUID().slice(0, 8),
    sku, qty, customer,
    delivery_date: b.delivery_date || isoPlusDays(2),
    status: "placed",
    inventory_remaining: remaining,
    created_at: new Date().toISOString(),
  };
  await ddb.send(new PutCommand({ TableName: ORD, Item: order }));
  return resp(201, order);
};
