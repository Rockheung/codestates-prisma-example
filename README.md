# 코드스테이츠 2020년 3월 온라인 기술세미나 (3/31) - 다 된 DB에 Prisma 얹기


## TL;DR

Database(samples)를 Mysql에 집어넣고 `prisma introspect`로 `datamodel.prisma`를 생성하여 알맞게 변형시킨다. 이를 기반으로 `prisma deploy` 로 새로운 Database(prism_app@devel)를 생성한다. Database(samples)에서 Database(prism_app@devel)로 dump한다.
Playground에 접속하여 생각했던 대로 데이터를 가져올 수 있는지 확인한다.


## 전후 상황

- 당신의 회사는 협력업체로부터 Database를 사서 당신에게 던져주었다.
- 당신이 맡은 역할은 이 Database를 바탕으로 Graphql 서버를 구성하는 것이다.


## Requirements

- Mac OS(?) - 다른 플랫폼에서는 테스트 안해봤습니다!
- Nodejs, Docker (with docker-compose), Mysql client


## Step One

레포지토리를 가져와 필요한 데이터를 세팅한다.
`postinstall.sh`에 일련의 작업들이 정의되어 있다. 공개된 employees dump 파일을 다운받아 DB버전(5.7)에 맞게 시스템 변수명 등을 수정한다.

```bash
$ git clone https://github.com/Rockheung/codestates-prisma-example.git
$ npm install
```

## Step Two

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
# OR just type `npx prisma introspect` and interact with it
```

datamodel-1585xxxxx.prisma와 같은 파일이 만들어진다. 이 파일을 바탕으로 Prisma에서 사용할 새 DB에 대한 모델을 정의할 수 있다.

## Step Three




## Ref.

https://dev.mysql.com/doc/employee/en/

https://www.prisma.io/docs/