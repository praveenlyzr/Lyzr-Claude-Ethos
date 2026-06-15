// GET /inventory/{sku}[?want=N] — current stock and (with ?want) the DETERMINISTIC branch decision.
// The reorder QUANTITY is intentionally NOT computed here. That "Smart History" reasoning lives in
// the orchestration layer — an LLM node in the SuperFlow (and the gitagent) — fed by GET /history/{sku}.
// This keeps the backend dumb (data + atomic ops) so the AI logic sits visibly in the middle.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const INV = process.env.INVENTORY_TABLE;

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

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
    out.sufficient = sufficient ? "yes" : "no"; // string, for a clean Switch comparison
    out.shortfall = sufficient ? 0 : want - quantity;
  }
  return resp(200, out);
};
