# 코드스테이츠 2020년 3월 온라인 기술세미나 (3/31) - 다 된 DB에 Prisma 얹기


## TL;DR

Database(samples)를 Mysql에 집어넣고 `prisma introspect`로 `datamodel.prisma`를 생성하여 알맞게 변형시킨다. 이를 기반으로 `prisma deploy` 로 새로운 Database(prism_app@devel)를 생성한다. Database(samples)에서 Database(prism_app@devel)로 dump한다.
Playground에 접속하여 생각했던 대로 데이터를 가져올 수 있는지 확인한다.


## 전후 상황

- 당신은 DBA가 아니다. 데이터베이스에 빠삭하지 않다.
- 당신의 회사는 협력업체로부터 Database를 사서 당신에게 던져주었다.
- Forign key가 없고, 애플리케이션 수준에서 관계가 맺어져 있다.
- 당신이 맡은 역할은 이 Database를 바탕으로 Graphql 서버를 구성하는 것이다.
- 사용하게 될 DB의 스키마는 다음과 같다

![](https://dev.mysql.com/doc/employee/en/images/employees-schema.png)


## Requirements

- Mac OS(?) - 다른 플랫폼에서는 테스트 안해봤습니다!
- Prisma(v1), Nodejs, Docker (with docker-compose), Mysql client(CLI)


## Step One

레포지토리를 가져와 필요한 데이터를 세팅한다.
`postinstall.sh`에 일련의 작업들이 정의되어 있다. 공개된 employees dump 파일을 다운받아 DB버전(5.7)에 맞게 시스템 변수명 등을 수정하는 스크립트가 포함되어 있다.

```bash
$ git clone https://github.com/Rockheung/codestates-prisma-example.git
$ cd codestates-prisma-example
$ npm install
```

## Step Two

도커를 켜고 데이터베이스를 초기 세팅하는 과정이다. 약간의 시간이 걸린다.

```bash
# npm run db:start
$ npx dotenv -- docker-compose up -d

# npm run db:status
$ npx dotenv -- docker-compose logs -f

# npm run db:load
$ npx dotenv -- bash -c 'mysql \
  -h $DB_HOST \
  -P $DB_PORT \
  -u $DB_USER \
  -p$DB_PASS < employees_db/employees.sql'

# npm run db:introspect
$ npx dotenv -- bash -c 'prisma introspect \
  --mysql-host $DB_HOST \
  --mysql-port $DB_PORT \
  --mysql-db $SRC_DB_NAME \
  --mysql-user $DB_USER \
  --mysql-password $DB_PASS'
# Or just type `npx prisma introspect` and interact with it
```

datamodel-1585xxxxx.prisma와 같은 파일이 만들어진다. 이 파일을 바탕으로 Prisma에서 사용할 새 DB에 대한 모델을 정의할 수 있다.

## Step Three

만들어진 prisma datamodel 파일에 기반하여 `prisma deploy`는 데이터베이스(prism_app@devel)의 스키마를 만들 것이다. 여기서 필요한 전제는, `mysqldump`를 사용하여 데이터를 samples에서 prism_app@devel로 마이그레이션할 것이기 때문에 두 데이터베이스의 스키마가 같은 형태여야 한다는 것이다.

다음의 경우는 명확하다. 타입의 각 필드가 각 Column과 매핑된다. 물론 경우에 따라 필드를 임의로 추가하게 될 텐데, 이는 조금 이따가 살펴볼 것이다.

```SQL
CREATE TABLE employees (
  emp_no      INT             NOT NULL,
  birth_date  DATE            NOT NULL,
  first_name  VARCHAR(14)     NOT NULL,
  last_name   VARCHAR(16)     NOT NULL,
  gender      ENUM ('M','F')  NOT NULL,
  hire_date   DATE            NOT NULL,
  PRIMARY KEY (emp_no)
);
```

```prisma
type Employee @db(name: "employees") {
  emp_no:    Int!             @id
  birthDate: DateTime!        @db(name: "birth_date")
  firstName: String!          @db(name: "first_name")
  gender:    EmployeesGenderEnum!
  hireDate:  DateTime!        @db(name: "hire_date")
  lastName:  String!          @db(name: "last_name")
}
```

반대로 다음과 같이 명료하지 않은 테이블도 있는데, 다음을 보자.

```SQL
CREATE TABLE dept_manager (
   dept_no      CHAR(4)         NOT NULL,
   emp_no       INT             NOT NULL,
   from_date    DATE            NOT NULL,
   to_date      DATE            NOT NULL,
   PRIMARY KEY (emp_no,dept_no)
); 
```

위 테이블에 대한 prisma의 introspect 데이터모델은 다음과 같다. 바로 사용할 수 없는 형태이다.

```prisma
type DeptManager @db(name: "dept_manager") {
  # Multiple ID fields (compound indexes) are not supported
  # emp_no: Int! @id
  # Multiple ID fields (compound indexes) are not supported
  # dept_no: ID! @id
  fromDate: DateTime! @db(name: "from_date")
  toDate: DateTime! @db(name: "to_date")
}
```

이유는 위 테이블이 복합키(composite primary key)를 사용하고 있기 때문이다.Prisma는 이를 허용하지 않는데, 2개의 pk column은 2개의 @id directive로 변환된다. 다행히 이 테이블의 역할을 고민하면 굳이 복합키를 고민할 필요는 없다는 결론에 도달한다. pk로 사용되는 각각의 칼럼은 fk의 역할을 하고 있다. 다음과 같이 바꿔주자.

```prisma
type DeptManager @db(name: "dept_manager") {
  id: Int! @id
  deptNo: Department! @db(name: "dept_no") @relation(link: INLINE)
  empNo: Employee! @db(name: "emp_no") @relation(link: INLINE)
  fromDate: DateTime! @db(name: "from_date")
  toDate: DateTime! @db(name: "to_date")
}
```

Int 타입 id 필드를 추가하여 pk가 되도록 했고, 원래 데이터에는 해당 필드가 없지만 후에`INSERT`로 밀어넣을 때 자동으로 pk가 생성된다. 

의아한 부분이 있다. `Int` 타입이 `Employee` 타입으로 바뀌었다. 이는 prisma에서 관계를 정의할 때 사용하는 방식이다. 위 Column은 이제 employees 테이블과의 fk로 사용된다. 

아까 하다 만 얘기가 있다. 타입에 임의의 필드를 정의하는 경우다. 위의 예시에서 DeptManager 하위에 Employee 필드를 만들었다. 이는 결과적으로 Employee Resolver와 이어진다. 그렇다면 Employee에서 자신을 향하는 DeptManager들은 어떻게 Resolve할 수 있는가? 이는 다음과 같은 데이터모델 정의를 통해 가능하다.

```prisma
type Employee @db(name: "employees") {
  emp_no: Int! @id
  birthDate: DateTime! @db(name: "birth_date")
  firstName: String! @db(name: "first_name")  
  gender: EmployeesGenderEnum!
  hireDate: DateTime! @db(name: "hire_date")
  lastName: String! @db(name: "last_name")
  deptManagers: [DeptManager!]!
}
```

위 타입에서 deptManagers 필드는 실제로 데이터베이스에 생성되는 Column이 아니다. 하지만 위의 datamodel은 결과적으로 다음과 같은 Query를 가능하게 한다.

```GraphQL
query ($id: Int){
  employee(where: {emp_no: $id}) {
    deptManagers {
      id
      fromDate
    }
  }
}
```

이에 대한 결과값은 다음과 같을 것이다.

```json
{
  "data": {
    "employee": {
      "deptManagers": [
        {
          "id": 00000,
          "formDate": "2020-03-29T11:50:04.748Z"
        }
      ]
    }
  }
}
```

위와 같은 방식으로 1:N의 관계를 각각의 타입에 필요에 따라 정의하면 된다. 

자세한 관계 정의 방법은 여기서 좀 더 볼 수 있다. 

[=> Official Prisma Docs: Datamodel & Migration: Relation](https://www.prisma.io/docs/datamodel-and-migrations/datamodel-MYSQL-knul/#relations)

정의가 끝났으면 파일명을 `datamodel.prism`로 수정한다. 이 모델을 바탕으로 prism_app@devel의 DB 스키마가 만들어질 것이다.

```bash
# npm run db:migration
$ npx dotenv -- prisma deploy
```

성공했다면, 이제 새 포대에 들이부을 시간이다.

```bash
$ npx dotenv -- bash dump.sh
```

## Step Four

Prisma 컨테이너에는 `npm run db:start` 이후로 주욱 Playground가 실행 중이다. 들어가보자. 그 전에, 우리는 prisma 설정 파일에서 secret을 정의했다. 이는 prisma 컨테이너 내부의 인증 로직을 활성화시킨다. 다음 명령어로 token을 발급받으면 된다.

```bash
# npm run db:token
$ npx dotenv -- prisma token
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7InNlcnZpY2UiOiJwcmlzbV9hcHBAZGV2ZWwiLCJyb2xlcyI6WyJhZG1pbiJdfSwiaWF0IjoxNTg1NDg0MzE4LCJleHAiOjE1ODYwODkxMTh9.Yuo86I084NoJijrOwc1Prjm1-QttEJjtGmsPO3fkIx0
# {
#   "data": {
#     "service": "prism_app@devel",
#     "roles": [
#       "admin"
#     ]
#   },
#   "iat": 1585484318,
#   "exp": 1586089118
# }
```
위 토큰을 가지고 다음 주소로 접근하면 된다. 

http://127.0.0.1:8446/prism_app/devel

playground가 열리는데, 좌하단의 HTTP HEADERS를 클릭하여 연 후에, 위의 토큰을 JSON형태로 다음과 같이 넣는다

```json
{
  "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjp7InNlcnZpY2UiOiJwcmlzbV9hcHBAZGV2ZWwiLCJyb2xlcyI6WyJhZG1pbiJdfSwiaWF0IjoxNTg1NDg0MzE4LCJleHAiOjE1ODYwODkxMTh9.Yuo86I084NoJijrOwc1Prjm1-QttEJjtGmsPO3fkIx0"
}
```

이제 가능한 쿼리들을 DOCS 에서 확인할 수 있다. 데이터베이스에서 원하는 종류의 데이터를 잘 가져올 수 있는지 확인해보자. 먼저, employees는 잘 있을까? 어떤 sql문으로 데이터를 불러오는지도 로그를 통해 확인해보자.

```GraphQL
{
  employees(first: 3) {
    emp_no
    firstName
    lastName
  }
}
```

```sql
select
  `Alias`.`emp_no`,
  `Alias`.`first_name`,
  `Alias`.`last_name`
from `prism_app@devel`.`employees` as `Alias`
where 1 = 1
order by `Alias`.`emp_no` asc
limit 4
offset 0
```

```json
{
  "data": {
    "employees": [
      {
        "emp_no": 10001,
        "firstName": "Georgi",
        "lastName": "Facello"
      },
      {
        "emp_no": 10002,
        "firstName": "Bezalel",
        "lastName": "Simmel"
      },
      {
        "emp_no": 10003,
        "firstName": "Parto",
        "lastName": "Bamford"
      }
    ]
  }
}
```

평소에 Georgi에 관심이 있어서 그의 성별과 부서를 확인해 보려 한다.

```GraphQL
{
  employee(where: {emp_no: 10001}) {
    emp_no
    firstName
    lastName
    gender
    deptEmp {
      deptNo {
        dept_no
        deptName
      }
    }
  }
}
```

```sql
select
  `prism_app@devel`.`employees`.`emp_no`,
  `prism_app@devel`.`employees`.`first_name`,
  `prism_app@devel`.`employees`.`gender`,
  `prism_app@devel`.`employees`.`last_name`
from `prism_app@devel`.`employees`
where `prism_app@devel`.`employees`.`emp_no` = 10001;

select
  `Alias`.`id`,
  `Alias`.`dept_no`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`emp_no` as `__ParentModel__`
from `prism_app@devel`.`dept_emp` as `Alias`
  join `prism_app@devel`.`dept_emp` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`emp_no` in (10001)
order by `RelationTable`.`id` asc;

select
  `Alias`.`dept_no`,
  `Alias`.`dept_name`
from `prism_app@devel`.`departments` as `Alias`
where `Alias`.`dept_no` in ('d005')
order by `Alias`.`dept_no` asc
limit 2147483647
offset 0;
```


```json
{
  "data": {
    "employee": {
      "emp_no": 10001,
      "lastName": "Facello",
      "firstName": "Georgi",
      "deptEmp": [
        {
          "deptNo": {
            "dept_no": "d005",
            "deptName": "Development"
          }
        }
      ],
      "gender": "M"
    }
  }
}
```

아쉽게도 Georgi는 남자였다.


...앞서 사용한 토큰의 payload를 살펴보면 유효 기간이 일주일밖에 되지 않는다. 만약 스크립트 자동화에 사용하고자 한다면, 그리고 바꾸기 귀찮고 서버사이드에서 사용할 목적이라면 다음을 통해 더 긴 유효기간인 키를 발급받아 사용하면 된다. 이 키는 참고로 유효기간이 5년이다.

```bash
# npm run token:dev
$ npx dotenv -- prisma cluster-token
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJncmFudHMiOlt7InRhcmdldCI6IiovKiIsImFjdGlvbiI6IioifV0sImlhdCI6MTU4NTQ4NDU3MSwiZXhwIjoxNzQzMjcyNTcxfQ.VZGgYt0-_fIJ-LD12OI2DEwMAN5pfW1nn5XlC2AG7Rw
# {
#   "grants": [
#     {
#       "target": "*/*",
#       "action": "*"
#     }
#   ],
#   "iat": 1585484571,
#   "exp": 1743272571
# }
```

cluster-token은 사실 Prisma Management에서 사용하는 데에 목적이 있다. 다음 주소로 접속하면 playground DOCS에 나타나는 Queris가 좀 다를 것이다. Prisma 컨테이너를 컨트롤할 수 있는 API다.

http://127.0.0.1:8446/management

다음 문서에서 좀 더 자세한 정보를 볼 수 있다.

[=> Official Prisma Docs: The Management API](https://www.prisma.io/docs/prisma-server/management-api-foe1/)


## Step Five

dept_emp 테이블은 사실 employees 테이블과 departments 테이블간의 M:N관계를 나타낸다. 간단히 살펴보자.

앞서 별 관심은 없지만 성별을 알 수 있었던 Georgi가 개발(Development) 부서인 것은 알게 되었다. 그 부서의 deptManager는 누구인가? 1:N의 관계로 맺어져 있는데 부서장은 한 명이어야 하는 것 아닌가? 데이터의 형태를 알아보고자 다음과 같은 쿼리를 날려보았다.

```graphql
{
  employee(where: {emp_no: 10001}) {
    emp_no
    firstName
    lastName
    titles {
      title
      fromDate
      toDate
    }
    deptEmp {
      deptNo {
        dept_no
        deptName
        deptManagers {
          fromDate
          toDate
          empNo {
            emp_no
            firstName
            lastName
            hireDate
          }
        }
      }
    }
  }
}
```

```sql
select
  `prism_app@devel`.`employees`.`first_name`,
  `prism_app@devel`.`employees`.`last_name`,
  `prism_app@devel`.`employees`.`emp_no`
from `prism_app@devel`.`employees`
where `prism_app@devel`.`employees`.`emp_no` = 10001

select
  `Alias`.`id`,
  `Alias`.`dept_no`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`emp_no` as `__ParentModel__`
from `prism_app@devel`.`dept_emp` as `Alias`
  join `prism_app@devel`.`dept_emp` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`emp_no` in (10001)
order by `RelationTable`.`id` asc

select
  `Alias`.`from_date`,
  `Alias`.`title`,
  `Alias`.`to_date`,
  `Alias`.`id`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`emp_no` as `__ParentModel__`
from `prism_app@devel`.`titles` as `Alias`
  join `prism_app@devel`.`titles` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`emp_no` in (10001)
order by `RelationTable`.`id` asc

select
  `Alias`.`dept_no`,
  `Alias`.`dept_name`
from `prism_app@devel`.`departments` as `Alias`
where `Alias`.`dept_no` in ('d005')
order by `Alias`.`dept_no` asc
limit 2147483647
offset 0

select
  `Alias`.`id`,
  `Alias`.`to_date`,
  `Alias`.`from_date`,
  `Alias`.`emp_no`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`dept_no` as `__ParentModel__`
from `prism_app@devel`.`dept_manager` as `Alias`
  join `prism_app@devel`.`dept_manager` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`dept_no` in ('d005')
order by `RelationTable`.`id` asc

select
  `Alias`.`emp_no`,
  `Alias`.`first_name`,
  `Alias`.`last_name`,
  `Alias`.`hire_date`
from `prism_app@devel`.`employees` as `Alias`
where `Alias`.`emp_no` in (
  110511, 110567
)
order by `Alias`.`emp_no` asc
limit 2147483647
offset 0
```

```json
{
  "data": {
    "employee": {
      "emp_no": 10001,
      "titles": [
        {
          "title": "Senior Engineer",
          "fromDate": "1986-06-26T00:00:00.000Z",
          "toDate": "9999-01-01T00:00:00.000Z"
        }
      ],
      "lastName": "Facello",
      "firstName": "Georgi",
      "deptEmp": [
        {
          "deptNo": {
            "dept_no": "d005",
            "deptName": "Development",
            "deptManagers": [
              {
                "fromDate": "1985-01-01T00:00:00.000Z",
                "toDate": "1992-04-25T00:00:00.000Z",
                "empNo": {
                  "emp_no": 110511,
                  "firstName": "DeForest",
                  "lastName": "Hagimont",
                  "hireDate": "1985-01-01T00:00:00.000Z"
                }
              },
              {
                "fromDate": "1992-04-25T00:00:00.000Z",
                "toDate": "9999-01-01T00:00:00.000Z",
                "empNo": {
                  "emp_no": 110567,
                  "firstName": "Leon",
                  "lastName": "DasSarma",
                  "hireDate": "1986-10-21T00:00:00.000Z"
                }
              }
            ]
          }
        }
      ]
    }
  }
}
```

아, 과거의 부서장 또한 기록이 되어 있었다. M:N관계인 것을 납득했다. 또한 마찬가지로 Georgi의 직책 또한 그 변경 이력을 추적할 수 있도록 DB가 구성되어 있음을 알 수 있다. 그렇다면 현재의 직위나 부서장만을 알고 싶다면? Prisma는 이미 계획이 다 있다. 다음과 같이 조건을 걸면 된다. 각 타입별로 어떤 정렬 조건을 걸 수 있는지 Enum으로 미리 정의해 준다. playground의 Docs를 보면 Prisma의 계획을 좀 더 자세히 알 수 있다.

```graphql
{
  employee(where: {emp_no: 10001 }) {
    emp_no
    firstName
    lastName
    titles(orderBy: fromDate_DESC, first:1) {
      title
      fromDate
      toDate
    }
    deptEmp {
      deptNo {
        dept_no
        deptName
        deptManagers(orderBy: fromDate_DESC, first:1) {
          fromDate
          toDate
          empNo {
            emp_no
            firstName
            lastName
            hireDate
          }
        }
      }
    }
  }
}
```

```sql
select
  `prism_app@devel`.`employees`.`first_name`,
  `prism_app@devel`.`employees`.`last_name`,
  `prism_app@devel`.`employees`.`emp_no`
from `prism_app@devel`.`employees`
where `prism_app@devel`.`employees`.`emp_no` = 10001

select
  `Alias`.`id`,
  `Alias`.`dept_no`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`emp_no` as `__ParentModel__`
from `prism_app@devel`.`dept_emp` as `Alias`
  join `prism_app@devel`.`dept_emp` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`emp_no` in (10001)
order by `RelationTable`.`id` asc

(select
  `Alias`.`from_date`,
  `Alias`.`title`,
  `Alias`.`to_date`,
  `Alias`.`id`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`emp_no` as `__ParentModel__`
from `prism_app@devel`.`titles` as `Alias`
  join `prism_app@devel`.`titles` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`emp_no` = 10001
order by
  `from_date` desc,
  `__RelatedModel__` asc
limit 2
offset 0)

select
  `Alias`.`dept_no`,
  `Alias`.`dept_name`
from `prism_app@devel`.`departments` as `Alias`
where `Alias`.`dept_no` in ('d005')
order by `Alias`.`dept_no` asc
limit 2147483647
offset 0

(select
  `Alias`.`id`,
  `Alias`.`to_date`,
  `Alias`.`from_date`,
  `Alias`.`emp_no`,
  `RelationTable`.`id` as `__RelatedModel__`,
  `RelationTable`.`dept_no` as `__ParentModel__`
from `prism_app@devel`.`dept_manager` as `Alias`
  join `prism_app@devel`.`dept_manager` as `RelationTable`
  on `Alias`.`id` = `RelationTable`.`id`
where `RelationTable`.`dept_no` = 'd005'
order by
  `from_date` desc,
  `__RelatedModel__` asc
limit 2
offset 0)

select
  `Alias`.`emp_no`,
  `Alias`.`first_name`,
  `Alias`.`last_name`,
  `Alias`.`hire_date`
from `prism_app@devel`.`employees` as `Alias`
where `Alias`.`emp_no` in (110567)
order by `Alias`.`emp_no` asc
limit 2147483647
offset 0
```

```json
{
  "data": {
    "employee": {
      "emp_no": 10001,
      "titles": [
        {
          "title": "Senior Engineer",
          "fromDate": "1986-06-26T00:00:00.000Z",
          "toDate": "9999-01-01T00:00:00.000Z"
        }
      ],
      "lastName": "Facello",
      "firstName": "Georgi",
      "deptEmp": [
        {
          "deptNo": {
            "dept_no": "d005",
            "deptName": "Development",
            "deptManagers": [
              {
                "fromDate": "1992-04-25T00:00:00.000Z",
                "toDate": "9999-01-01T00:00:00.000Z",
                "empNo": {
                  "emp_no": 110567,
                  "firstName": "Leon",
                  "lastName": "DasSarma",
                  "hireDate": "1986-10-21T00:00:00.000Z"
                }
              }
            ]
          }
        }
      ]
    }
  }
}
```

## Step Further...

지금까지 Prisma를 다 된 DB에 얹어 보았다. 그렇다면 실제로 production 환경에서도 이런 docker container를 띄워 써야 하는가? 혹시 요청이 몰려 다운타임이 발생할 수도 있지 않을까? 이에 대해서는 aws의 fargate를 활용하여 걱정을 덜 수 있지 않을까 한다.

[Github: prisma/prisma-templates](https://github.com/prisma/prisma-templates/blob/master/aws/fargate.yml)

[Prisma Docs (v1.13): AWS Fargate](https://www.prisma.io/docs/1.13/tutorials/deploy-prisma-servers/aws-fargate-joofei3ahd)

이를 이용하면 짧은 기간 내에 로드밸런싱까지 지원하는 백엔드를 구성할 수 있다. 


## Step Reset


뭔가 잘못되었고 처음부터 다시 시작해야겠다는 생각이 든다면 다음 명령들을 날려주자.

```bash
# npm run db:kill
$ dotenv -- docker-compose down && rm -rf .mysql
```

`.mysql`에는 도커 컨테이너의 mysql server가 사용하는 파일들이 들어가 있다. 데이터베이스에 담기는 정보 등등의 실제 DB서버를 운용하는데 사용되는 파일 및 폴더가 위치한다.

```bash
$ git reset HEAD . && git checkout . && git clean -dxf
```

레포지토리를 순수한 처음의 모습으로 돌린다. 이전까지 뭔가 작업한 게 있고 남기고 싶다면 `git stash`를 활용하자.

```bash
$ npm i
```

## Ref.

https://www.prisma.io/docs/

https://dev.mysql.com/doc/employee/en/

https://www.lesstif.com/pages/viewpage.action?pageId=17105804