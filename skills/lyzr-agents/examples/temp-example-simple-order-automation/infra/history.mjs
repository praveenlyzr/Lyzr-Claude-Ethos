// GET /history/{sku} — this SKU's past orders plus simple stats, so the orchestration layer
// (an LLM node in the SuperFlow, or the gitagent) can REASON about how much to reorder.
// The backend only serves the data; it does not decide the reorder quantity. Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const ORD = process.env.ORDERS_TABLE;

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const sku = event?.pathParameters?.sku;
  if (!sku) return resp(400, { error: "sku required in path" });

  let items = [];
  let ExclusiveStartKey;
  do {
    const out = await ddb.send(new ScanCommand({
      TableName: ORD,
      FilterExpression: "sku = :s",
      ExpressionAttributeValues: { ":s": sku },
      ExclusiveStartKey,
    }));
    items = items.concat(out.Items || []);
    ExclusiveStartKey = out.LastEvaluatedKey;
  } while (ExclusiveStartKey);

  // newest first
  items.sort((a, b) => String(b.created_at || "").localeCompare(String(a.created_at || "")));
  const qtys = items.map((o) => Number(o.qty) || 0);
  const total_qty = qtys.reduce((s, n) => s + n, 0);
  const stats = {
    orders: items.length,
    total_qty,
    avg_qty: items.length ? Math.round(total_qty / items.length) : 0,
    max_qty: qtys.length ? Math.max(...qtys) : 0,
  };
  const orders = items.map((o) => ({ order_id: o.order_id, qty: Number(o.qty) || 0, customer: o.customer, created_at: o.created_at }));
  return resp(200, { sku, stats, orders });
};
