// POST /orders {sku, qty, customer, delay_days?, delivery_date?} — atomically reserves stock and
// records the order. Accepts query OR JSON body. Delivery date = explicit delivery_date, else
// today + delay_days (default 2). Returns 409 if stock is insufficient. Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { randomUUID } from "crypto";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const INV = process.env.INVENTORY_TABLE;
const ORD = process.env.ORDERS_TABLE;

const params = (e) => { let b = {}; try { b = JSON.parse(e?.body || "{}"); } catch {} return { ...(e?.queryStringParameters || {}), ...b }; };
const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});
const isoPlusDays = (d) => new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);

export const handler = async (event) => {
  const p = params(event);
  const sku = p.sku;
  const qty = Number(p.qty);
  const customer = p.customer || "anonymous";
  if (!sku || !Number.isFinite(qty) || qty <= 0) return resp(400, { error: "sku and positive qty required" });

  const delay = Number(p.delay_days);
  const delivery_date = p.delivery_date || isoPlusDays(Number.isFinite(delay) && delay >= 0 ? delay : 2);

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
    if (e.name === "ConditionalCheckFailedException") return resp(409, { error: "insufficient stock", sku, requested: qty });
    throw e;
  }

  const order = {
    order_id: "ord_" + randomUUID().slice(0, 8),
    sku, qty, customer, delivery_date,
    status: "placed",
    inventory_remaining: remaining,
    created_at: new Date().toISOString(),
  };
  await ddb.send(new PutCommand({ TableName: ORD, Item: order }));
  return resp(201, order);
};
