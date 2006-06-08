require 'test/unit'
require 'test/FbTestCases'
require 'fb.so'
require 'date'

include Fb

class DataTypesTestCases < Test::Unit::TestCase
  include FbTestCases
  
  def gen_i(i)
    i
  end
  
  def gen_si(i)
    i
  end
  
  def gen_bi(i)
    i * 1000000000
  end
  
  def gen_f(i)
    i / 2
  end
  
  def gen_d(i)
    i * 3333 / 2
  end
  
  def gen_c(i)
    "%c" % (i + 64)
  end
  
  def gen_c10(i)
    gen_c(i) * 5
  end
  
  def gen_vc(i)
    gen_c(i)
  end
  
  def gen_vc10(i)
    gen_c(i) * i
  end
  
  def gen_vc10000(i)
    gen_c(i) * i * 1000
  end
  
  def gen_dt(i)
    Date.civil(2000, i+1, i+1)
  end
  
  def gen_tm(i)
    Time.utc(1990, 1, 1, 12, i, i)
  end
  
  def gen_ts(i)
    Time.local(2006, 1, 1, i, i, i)
  end
  
  def test_insert_basic_types
    sql_schema = <<-END
      create table TEST (
        I INTEGER,
        SI SMALLINT,
        BI BIGINT,
        F FLOAT, 
        D DOUBLE PRECISION,
        C CHAR,
        C10 CHAR(10),
        VC VARCHAR(1),
        VC10 VARCHAR(10),
        VC10000 VARCHAR(10000),
        DT DATE,
        TM TIME,
        TS TIMESTAMP);
      END
    sql_insert = <<-END
      insert into test 
        (I, SI, BI, F, D, C, C10, VC, VC10, VC10000, DT, TM, TS) 
        values
        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      END
    sql_select = "select * from TEST order by I"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      connection.transaction do
        10.times do |i|
          connection.execute(
            sql_insert, 
            gen_i(i), gen_si(i), gen_bi(i),
            gen_f(i), gen_d(i),
            gen_c(i), gen_c10(i), gen_vc(i), gen_vc10(i), gen_vc10000(i), 
            gen_dt(i), gen_tm(i), gen_ts(i))
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :hash do |row|
          assert_equal gen_i(i), row["I"], "INTEGER"
          assert_equal gen_si(i), row["SI"], "SMALLINT"
          assert_equal gen_bi(i), row["BI"], "BIGINT"
          assert_equal gen_f(i), row["F"], "FLOAT"
          assert_equal gen_d(i), row["D"], "DOUBLE PRECISION"
          assert_equal gen_c(i), row["C"], "CHAR"
          assert_equal gen_c10(i).ljust(10), row["C10"], "CHAR(10)"
          assert_equal gen_vc(i), row["VC"], "VARCHAR(1)"
          assert_equal gen_vc10(i), row["VC10"], "VARCHAR(10)"
          assert_equal gen_vc10000(i), row["VC10000"], "VARCHAR(10000)"
          assert_equal gen_dt(i), row["DT"], "DATE"
          #assert_equal gen_tm(i).strftime("%H%M%S"), row["TM"].utc.strftime("%H%M%S"), "TIME"
          assert_equal gen_ts(i), row["TS"], "TIMESTAMP"
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_blobs_text
    sql_schema = "create table test (id int, name varchar(20), memo blob sub_type text)"
    sql_insert = "insert into test (id, name, memo) values (?, ?, ?)"
    sql_select = "select * from test order by id"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      memo = IO.read("fb.c")
      assert memo.size > 50000
      connection.transaction do
        10.times do |i|
          connection.execute(sql_insert, i, i.to_s, memo);
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :hash do |row|
          assert_equal i, row["ID"]
          assert_equal i.to_s, row["NAME"]
          assert_equal memo, row["MEMO"]
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_blobs_binary
    sql_schema = "create table test (id int, name varchar(20), attachment blob segment size 1000)"
    sql_insert = "insert into test (id, name, attachment) values (?, ?, ?)"
    sql_select = "select * from test order by id"
    #filename = "data.dat"
    filename = "fb.c"
    Database.create(@parms) do |connection|
      connection.execute(sql_schema);
      attachment = File.open(filename,"rb") do |f|
        f.read * 3
      end
      assert (attachment.size > 150000), "Not expected size"
      connection.transaction do
        3.times do |i|
          connection.execute(sql_insert, i, i.to_s, attachment);
        end
      end
      connection.execute(sql_select) do |cursor|
        i = 0
        cursor.each :array do |row|
          assert_equal i, row[0], "ID's do not match"
          assert_equal i.to_s, row[1], "NAME's do not match"
          assert_equal attachment.size, row[2].size, "ATTACHMENT sizes do not match"
          i += 1
        end
      end
      connection.drop
    end
  end

  def test_insert_incorrect_types
    cols = %w{ I SI BI F D C C10 VC VC10 VC10000 DT TM TS }
    types = %w{ INTEGER SMALLINT BIGINT FLOAT DOUBLE\ PRECISION CHAR CHAR(10) VARCHAR(1) VARCHAR(10) VARCHAR(10000) DATE TIME TIMESTAMP }
    sql_schema = "";
    assert_equal cols.size, types.size
    cols.size.times do |i|
      sql_schema << "CREATE TABLE TEST_#{cols[i]} (VAL #{types[i]});\n"
    end
    Database.create(@parms) do |connection|
      connection.execute_script(sql_schema)
      cols.size.times do |i|
        sql_insert = "INSERT INTO TEST_#{cols[i]} (VAL) VALUES (?);"
        if cols[i] == 'I'
          assert_raise TypeError do
            connection.execute(sql_insert, "five")
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 5000000000)
          end
        elsif cols[i] == 'SI'
          assert_raise TypeError do
            connection.execute(sql_insert, "five")
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 100000)
          end
        elsif cols[i] == 'BI'
          assert_raise TypeError do
            connection.execute(sql_insert, "five")
          end
          assert_raise TypeError do
            connection.execute(sql_insert, Time.now)
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 184467440737095516160) # 2^64 * 10
          end
        elsif cols[i] == 'F'
          assert_raise TypeError do
            connection.execute(sql_insert, "five")
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 10 ** 39)
          end
        elsif cols[i] == 'D'
          assert_raise TypeError do
            connection.execute(sql_insert, "five")
          end
        elsif cols[i] == 'VC'
          assert_raise RangeError do
            connection.execute(sql_insert, "too long")
          end
          assert_raise RangeError do
            connection.execute(sql_insert, 1.0/3.0)
          end
        elsif cols[i] ==  'VC10'
          assert_raise RangeError do
            connection.execute(sql_insert, 1.0/3.0)
          end
        elsif cols[i].include?('VC10000')
          assert_raise RangeError do
            connection.execute(sql_insert, "X" * 10001)
          end
        elsif cols[i] == 'C'
          assert_raise RangeError do
            connection.execute(sql_insert, "too long")
          end
        elsif cols[i] == 'C10'
          assert_raise RangeError do
            connection.execute(sql_insert, Time.now)
          end
        elsif cols[i] == 'DT'
          assert_raise ArgumentError do
            connection.execute(sql_insert, Date)
          end
          assert_raise ArgumentError do
            connection.execute(sql_insert, 2006)
          end
        elsif cols[i] == 'TM'
          assert_raise TypeError do
            connection.execute(sql_insert, "2006/1/1")
          end
          assert_raise TypeError do
            connection.execute(sql_insert, 10000)
          end
        elsif cols[i] ==  'TS'
          assert_raise TypeError do
            connection.execute(sql_insert, "2006/1/1")
          end
          assert_raise TypeError do
            connection.execute(sql_insert, 10000)
          end
        end
      end
      connection.drop
    end
  end
end