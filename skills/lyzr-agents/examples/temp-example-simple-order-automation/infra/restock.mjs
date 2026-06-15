// POST /restock {sku, qty} — adds qty to a SKU's stock (creates the SKU if new). Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.INVENTORY_TABLE;

const parse = (e) => { try { return JSON.parse(e?.body || "{}"); } catch { return {}; } };
const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const b = parse(event);
  const sku = b.sku;
  const qty = Number(b.qty);
  if (!sku || !Number.isFinite(qty) || qty <= 0) return resp(400, { error: "sku and positive qty required" });
  const { Attributes } = await ddb.send(new UpdateCommand({
    TableName: TABLE,
    Key: { sku },
    UpdateExpression: "SET quantity = if_not_exists(quantity, :z) + :q",
    ExpressionAttributeValues: { ":q": qty, ":z": 0 },
    ReturnValues: "ALL_NEW",
  }));
  return resp(200, { sku, added: qty, quantity: Number(Attributes.quantity) });
};
