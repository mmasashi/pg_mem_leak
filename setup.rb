require_relative 'config'
require 'pg'

TOTAL_NUM_RECORDS = 50000
NUM_RECORDS_PER_QUERY = 100

class DataInsertClient

  def create_table
    query("CREATE TABLE #{TEST_PG_MEM_LEAK_TABLE_NAME} (id SERIAL primary key, value varchar(65535));")
  end

  def drop_table
    query("DROP TABLE IF EXISTS #{TEST_PG_MEM_LEAK_TABLE_NAME};")
  end

  def insert_records(num = TOTAL_NUM_RECORDS, num_per_query = NUM_RECORDS_PER_QUERY)
    connect do |client|
      n_times = num / num_per_query
      n_times.times do
        client.query(create_query(num_per_query))
      end
    end
  end

  def create_query(num = 100)
    "BEGIN; INSERT INTO #{TEST_PG_MEM_LEAK_TABLE_NAME} (value) values " + (["('#{'aaaaaaaaaa'*1000}')"]*num).join(',') + "; COMMIT;"
  end

  def connect
    client = PGconn.open(PG_DB_CONFIG)
    yield client
  ensure
    client.close if client
  end

  def query(query)
    connect do |client|
      client.query(query)
    end
  end
end

def main
  dc = DataInsertClient.new
  puts "Dropping #{TEST_PG_MEM_LEAK_TABLE_NAME} table if exists"
  dc.drop_table
  puts "Creating #{TEST_PG_MEM_LEAK_TABLE_NAME} table"
  dc.create_table
  puts "Inserting #{TOTAL_NUM_RECORDS} records to #{TEST_PG_MEM_LEAK_TABLE_NAME}"
  dc.insert_records
end

main
