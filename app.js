const ZongJi = require("zongji");

const {
  DB_HOST: host,
  DB_USER: user,
  DB_PORT: port,
  DB_PASS: password,
  DB_NAME: dbName,
  STAGING
} = process.env;

let zongji = new ZongJi({
  host: "127.0.0.1",
  port,
  user,
  password
});

const watchingTables = [
  "departments",
  "dept_emp",
  "dept_manager",
  "employees",
  "salaries",
  "titles"
];

// Each change to the replication log results in an event
zongji.on("binlog", function(evt) {
  const _evt = { ...evt };
  delete _evt._zongji;
  console.log(JSON.stringify(_evt, null, 2));
  if (evt.getEventName() === "query") {
    // console.log(evt.query.trim());
  }
  // evt.dump();
});

// Binlog must be started, optionally pass in filters
zongji.start({
  serverId: 1,
  includeEvents: ["query", "tablemap", "writerows", "updaterows", "deleterows"],
  includeSchema: {
    [`${dbName}@${STAGING}`]: true
  },
  startAtEnd: true
});
