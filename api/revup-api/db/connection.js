import pg from "pg";
import dotenv from "dotenv";

dotenv.config();

export const pool = new pg.Pool({
user: "Andrew",
password: "235727",
host: "localhost",
port: "5432",
database: "backfire",
});
