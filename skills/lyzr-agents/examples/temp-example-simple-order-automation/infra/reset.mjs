// POST /reset — restores inventory to the seeded stock and clears ALL order history.
// Use between demo runs to get a clean slate. Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, ScanCommand, BatchWriteCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const INV = process.env.INVENTORY_TABLE;
const ORD = process.env.ORDERS_TABLE;

// canonical demo state — keep in sync with infra/seed.json
const SEED = [
  { sku: "WIDGET-001", quantity: 50 },
  { sku: "GADGET-002", quantity: 3 },
  { sku: "GIZMO-003", quantity: 0 },
];

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

// delete every row in the orders table (paged scan + batched deletes)
async function clearOrders() {
  let cleared = 0;
  let ExclusiveStartKey;
  do {
    const out = await ddb.send(new ScanCommand({ TableName: ORD, ProjectionExpression: "order_id", ExclusiveStartKey }));
    const items = out.Items || [];
    for (let i = 0; i < items.length; i += 25) {
      const chunk = items.slice(i, i + 25);
      await ddb.send(new BatchWriteCommand({
        RequestItems: { [ORD]: chunk.map((it) => ({ DeleteRequest: { Key: { order_id: it.order_id } } })) },
      }));
      cleared += chunk.length;
    }
    ExclusiveStartKey = out.LastEvaluatedKey;
  } while (ExclusiveStartKey);
  return cleared;
}

export const handler = async () => {
  for (const it of SEED) {
    await ddb.send(new PutCommand({ TableName: INV, Item: { sku: it.sku, quantity: it.quantity } }));
  }
  const orders_cleared = await clearOrders();
  return resp(200, { reset: true, inventory: SEED, orders_cleared });
};
