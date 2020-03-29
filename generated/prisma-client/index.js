"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var prisma_lib_1 = require("prisma-client-lib");
var typeDefs = require("./prisma-schema").typeDefs;

var models = [
  {
    name: "Department",
    embedded: false
  },
  {
    name: "DeptEmp",
    embedded: false
  },
  {
    name: "DeptManager",
    embedded: false
  },
  {
    name: "Employee",
    embedded: false
  },
  {
    name: "EmployeesGenderEnum",
    embedded: false
  },
  {
    name: "Salary",
    embedded: false
  },
  {
    name: "Title",
    embedded: false
  }
];
exports.Prisma = prisma_lib_1.makePrismaClientClass({
  typeDefs,
  models,
  endpoint: `${process.env["PRISMA_ENDPOINT"]}`,
  secret: `${process.env["PRISMA_MANAGEMENT_API_SECRET"]}`
});
exports.prisma = new exports.Prisma();
