// POST /restock {sku, qty} — adds qty to stock (creates the SKU if new). Accepts query OR JSON body.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.INVENTORY_TABLE;

// params may arrive as query string (?sku=&qty=) or JSON body; body wins if both present
const params = (e) => { let b = {}; try { b = JSON.parse(e?.body || "{}"); } catch {} return { ...(e?.queryStringParameters || {}), ...b }; };
const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const p = params(event);
  const sku = p.sku;
  const qty = Number(p.qty);
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
