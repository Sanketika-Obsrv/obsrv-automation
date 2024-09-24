import psycopg2
import psycopg2.extras

from config import Config


class DatabaseService:

    def __init__(self):
        self.config = Config()

    def connect(self):
        db_host = self.config.find("postgres.host")
        db_port = self.config.find("postgres.port")
        db_user = self.config.find("postgres.user")
        db_password = self.config.find("postgres.password")
        database = self.config.find("postgres.dbname")
        db_connection = psycopg2.connect(
            database=database,
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
        )
        db_connection.autocommit = True
        return db_connection

    def execute_select_one(self, sql):
        db_connection = self.connect()
        cursor = db_connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute(sql)
        result = cursor.fetchone()
        db_connection.close()
        return result

    def execute_select_all(self, sql):
        db_connection = self.connect()
        cursor = db_connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute(sql)
        result = cursor.fetchall()
        db_connection.close()
        return result