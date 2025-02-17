package edu.washu.tag.tests;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.washu.tag.BaseTest;
import edu.washu.tag.TestQuery;
import edu.washu.tag.TestQuerySuite;
import edu.washu.tag.util.FileIOUtils;
import io.delta.sql.DeltaSparkSessionExtension;
import org.apache.spark.api.java.function.ForeachFunction;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.DataProvider;
import org.testng.annotations.Test;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class TestScoutQueries extends BaseTest {

  private final SparkSession spark = initSparkSession();
  private static final TestQuerySuite<?> exportedQueries = readQueries();
  private static final Logger logger = LoggerFactory.getLogger(TestScoutQueries.class);
  private static final List<String> knownUids = new ArrayList<>();
  private static final ForeachFunction<Row> rowProc = (row) -> knownUids.add(row.getString(0));

  @DataProvider(name = "known_queries")
  public Object[][] knownQueries() {
    return exportedQueries
        .getTestQueries()
        .stream()
        .map(query -> new Object[]{ query.getId() })
        .toArray(Object[][]::new);
  }

  @Test(dataProvider = "known_queries")
  public void testQueryById(String queryId) throws IOException {
    spark.sql("SELECT msh_10_message_control_id from syntheticdata").foreach(rowProc);
    final Map<String, String> sourceData = new ObjectMapper().readValue(new File("uids.json"), Map.class);
    final Map<String, String> missing = new HashMap<>();
    for (Map.Entry<String, String> entry : sourceData.entrySet()) {
      if (!knownUids.contains(entry.getKey())) {
        missing.put(entry.getKey(), entry.getValue());
      }
    }


    final TestQuery<?> query = exportedQueries
        .getTestQueries()
        .stream()
        .filter(testQuery -> testQuery.getId().equals(queryId))
        .findFirst()
        .orElseThrow(RuntimeException::new);

    logger.info("Performing query with spark: {}", query.getSql());
    query.getExpectedQueryResult().validateResult(spark.sql(query.getSql()));
  }

  private static TestQuerySuite<?> readQueries() {
    try {
      return new ObjectMapper().readValue(
          FileIOUtils.readResource("spark_queries.json"),
          TestQuerySuite.class
      );
    } catch (JsonProcessingException e) {
      throw new RuntimeException(e);
    }
  }

  private SparkSession initSparkSession() {
    final SparkSession spark = SparkSession.builder()
        .appName("TestClient")
        .master("local")
        .withExtensions(new DeltaSparkSessionExtension())
        .config(config.getSparkConfig())
        .getOrCreate();
    spark
        .read()
        .format("delta")
        .load(config.getDeltaLakeUrl())
        .createOrReplaceTempView(exportedQueries.getViewName());
    return spark;
  }

}
