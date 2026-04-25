{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": 0,
   "metadata": {
    "application/vnd.databricks.v1+cell": {
     "cellMetadata": {
      "byteLimit": 78643200,
      "rowLimit": 1000
     },
     "inputWidgets": {},
     "nuid": "dade9168-de9b-4daf-9224-bfc99c8c6072",
     "showTitle": false,
     "tableResultSettingsMap": {},
     "title": ""
    }
   },
   "outputs": [],
   "source": [
    "-- Title: Customer Count by Segment\n",
    "-- Visualization: Bar Chart | X: segment | Y: customers\n",
    "\n",
    "SELECT\n",
    "    segment,\n",
    "    customers,\n",
    "    total_spend,\n",
    "    avg_ltv,\n",
    "    pct_of_total\n",
    "FROM brazilian.gold.segment_summary\n",
    "ORDER BY customers DESC;"
   ]
  }
 ],
 "metadata": {
  "application/vnd.databricks.v1+notebook": {
   "computePreferences": null,
   "dashboards": [],
   "environmentMetadata": null,
   "inputWidgetPreferences": null,
   "language": "sql",
   "notebookMetadata": {
    "sqlQueryOptions": {
     "applyAutoLimit": true,
     "catalog": "workspace",
     "schema": "default"
    }
   },
   "notebookName": "Customer Count by Segment.dbquery.ipynb",
   "widgets": {}
  },
  "language_info": {
   "name": "sql"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 0
}
