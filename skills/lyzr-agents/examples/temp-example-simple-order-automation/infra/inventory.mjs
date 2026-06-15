// GET /inventory/{sku} — current stock for a SKU (0 if unknown). Public, no auth.
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand } from "@aws-sdk/lib-dynamodb";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.INVENTORY_TABLE;

const resp = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  const sku = event?.pathParameters?.sku;
  if (!sku) return resp(400, { error: "sku required in path" });
  const { Item } = await ddb.send(new GetCommand({ TableName: TABLE, Key: { sku } }));
  return resp(200, { sku, quantity: Item ? Number(Item.quantity) : 0, found: !!Item });
};
