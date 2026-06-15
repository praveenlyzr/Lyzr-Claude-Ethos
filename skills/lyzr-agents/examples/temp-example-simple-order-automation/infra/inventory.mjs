// GET /inventory/{sku}[?want=N] — current stock; if ?want is given, also returns the order decision.
// Smart History: when stock is short, the reorder amount is sized from this SKU's past orders
// (cover the next few typical orders) instead of a flat buffer — falling back to BASE_BUFFER
// when there is no history yet.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const INV = process.env.INVENTORY_TABLE;
const ORD = process.env.ORDERS_TABLE;
const BASE_BUFFER = 10; // safety stock when there's no order history to learn from
const COVER_ORDERS = 3; // a smart restock also aims to cover this many typical future orders

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

// pull this SKU's past orders so the reorder can be sized from real demand
async function orderHistory(sku) {
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
  const orders = items.length;
  const total_qty = items.reduce((s, o) => s + (Number(o.qty) || 0), 0);
  const avg_qty = orders ? Math.round(total_qty / orders) : 0;
  return { orders, total_qty, avg_qty };
}

export const handler = async (event) => {
  const sku = event?.pathParameters?.sku;
  if (!sku) return resp(400, { error: "sku required in path" });
  const q = event?.queryStringParameters || {};
  const { Item } = await ddb.send(new GetCommand({ TableName: INV, Key: { sku } }));
  const quantity = Item ? Number(Item.quantity) : 0;
  const out = { sku, quantity, found: !!Item };

  if (q.want !== undefined) {
    const want = Number(q.want) || 0;
    const sufficient = quantity >= want;
    out.want = want;
    out.sufficient = sufficient ? "yes" : "no";        // string, for a clean Switch comparison
    out.shortfall = sufficient ? 0 : want - quantity;
    if (sufficient) {
      out.restock_qty = 0;
    } else {
      // Smart History: size the safety buffer from past demand, never below the base buffer.
      const history = await orderHistory(sku);
      const smart_buffer = Math.max(BASE_BUFFER, history.avg_qty * COVER_ORDERS);
      out.restock_qty = out.shortfall + smart_buffer; // cover the gap + the smart buffer
      out.buffer = smart_buffer;
      out.history = history;                            // {orders, total_qty, avg_qty} — transparency
    }
  }
  return resp(200, out);
};
