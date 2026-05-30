const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const DB_PATH = path.join(__dirname, '../../pedidos.db');
let db;

function initDB() {
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  db.exec(schema);
  console.log('DB inicializada en', DB_PATH);
}

function getDB() {
  if (!db) throw new Error('DB no inicializada. Llama initDB() primero.');
  return db;
}

module.exports = { initDB, getDB };
