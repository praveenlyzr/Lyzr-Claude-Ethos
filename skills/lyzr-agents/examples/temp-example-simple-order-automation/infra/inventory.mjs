// GET /inventory/{sku}[?want=N] — current stock; if ?want is given, also returns the order decision.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.INVENTORY_TABLE;
const BUFFER = 10; // restock a little extra above the shortfall

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const sku = event?.pathParameters?.sku;
  if (!sku) return resp(400, { error: "sku required in path" });
  const q = event?.queryStringParameters || {};
  const { Item } = await ddb.send(new GetCommand({ TableName: TABLE, Key: { sku } }));
  const quantity = Item ? Number(Item.quantity) : 0;
  const out = { sku, quantity, found: !!Item };
  if (q.want !== undefined) {
    const want = Number(q.want) || 0;
    const sufficient = quantity >= want;
    out.want = want;
    out.sufficient = sufficient ? "yes" : "no";       // string, for a clean Switch comparison
    out.shortfall = sufficient ? 0 : want - quantity;
    out.restock_qty = sufficient ? 0 : want - quantity + BUFFER;
  }
  return resp(200, out);
};
