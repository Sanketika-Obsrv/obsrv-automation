import json
import requests

login_url = 'http://a1c470914e19e46a48bbc1a607c5ecdc-672264420.us-east-2.elb.amazonaws.com:8088/api/v1/security/login'
headers = {'Content-Type': 'application/json'}
data = {
    'username': 'admin',
    'password': 'admin123',
    'provider': 'db',
    'refresh': True
}
jwt_token = ""
csrf_token = ""

login_response = requests.post(login_url, headers=headers, json=data)

if login_response.status_code == 200:
    jwt_token = login_response.json()['access_token']
    print('Token Generated')
else:
    print('Failed to generate token. Status code:', login_response.status_code)

import json

create_chart_url = "http://a1c470914e19e46a48bbc1a607c5ecdc-672264420.us-east-2.elb.amazonaws.com:8088/api/v1/chart"

time_series_chart_payload = json.dumps({
  "slice_name": "dataset-summary",
  "viz_type": "echarts_timeseries_bar",
  "params": "{\n  \"adhoc_filters\": [],\n  \"annotation_layers\": [],\n  \"color_scheme\": \"d3Category10\",\n  \"comparison_type\": \"values\",\n  \"datasource\": \"1__table\",\n  \"extra_form_data\": {},\n  \"forecastInterval\": 0.8,\n  \"forecastPeriods\": 10,\n  \"granularity_sqla\": \"__time\",\n  \"groupby\": [\n    \"dataset\",\n    \"__time\"\n  ],\n  \"legendMargin\": 10,\n  \"legendOrientation\": \"bottom\",\n  \"legendType\": \"scroll\",\n  \"logAxis\": false,\n  \"metrics\": [\n    \"count\"\n  ],\n  \"minorSplitLine\": true,\n  \"only_total\": true,\n  \"order_desc\": true,\n  \"orientation\": \"vertical\",\n  \"rich_tooltip\": true,\n  \"row_limit\": 10000,\n  \"show_legend\": true,\n  \"show_value\": true,\n  \"slice_id\": 6,\n  \"stack\": false,\n  \"time_grain_sqla\": \"P1D\",\n  \"time_range\": \"No filter\",\n  \"tooltipSortByMetric\": true,\n  \"tooltipTimeFormat\": \"%d/%m/%Y\",\n  \"truncateYAxis\": false,\n  \"truncate_metric\": true,\n  \"viz_type\": \"echarts_timeseries_bar\",\n  \"xAxisLabelRotation\": 0,\n  \"x_axis_time_format\": \"%d/%m/%Y\",\n  \"x_axis_title\": \"Time Range\",\n  \"x_axis_title_margin\": 15,\n  \"y_axis_bounds\": [\n    null,\n    null\n  ],\n  \"y_axis_format\": \".3s\",\n  \"y_axis_title\": \"Count\",\n  \"y_axis_title_margin\": 15,\n  \"y_axis_title_position\": \"Left\",\n  \"zoomable\": true\n}",
  "cache_timeout": None,
  "datasource_id": "1",
  "datasource_type": "table"
})

event_validator_processing_time_payload = json.dumps({
  "slice_name": "event_validator_avg_processing_time",
  "viz_type": "big_number_total",
  "params": "{\n  \"adhoc_filters\": [],\n  \"datasource\": \"1__table\",\n  \"extra_form_data\": {},\n  \"force_timestamp_formatting\": false,\n  \"granularity_sqla\": \"__time\",\n  \"header_font_size\": 0.4,\n  \"metric\": {\n    \"aggregate\": \"AVG\",\n    \"column\": {\n      \"advanced_data_type\": null,\n      \"certification_details\": null,\n      \"certified_by\": null,\n      \"column_name\": \"event_validator_job_processing_time\",\n      \"description\": null,\n      \"expression\": null,\n      \"filterable\": true,\n      \"groupby\": true,\n      \"id\": 6,\n      \"is_certified\": false,\n      \"is_dttm\": false,\n      \"python_date_format\": null,\n      \"type\": \"FLOAT\",\n      \"type_generic\": 0,\n      \"verbose_name\": null,\n      \"warning_markdown\": null\n    },\n    \"expressionType\": \"SIMPLE\",\n    \"hasCustomLabel\": false,\n    \"isNew\": false,\n    \"label\": \"AVG(event_validator_job_processing_time)\",\n    \"optionName\": \"metric_bbwf5s2i055_8a3t6ovz1lc\",\n    \"sqlExpression\": null\n  },\n  \"subheader\": \"Event Validator - Avg Processing Time\",\n  \"subheader_font_size\": 0.125,\n  \"time_format\": \"%d/%m/%Y\",\n  \"time_grain_sqla\": \"PT10M\",\n  \"time_range\": \"2023-01-01T09:40:00 : now\",\n  \"viz_type\": \"big_number_total\",\n  \"y_axis_format\": \"DURATION\"\n}",
  "cache_timeout": None,
  "datasource_id": "1",
  "datasource_type": "table"
})

payloads = [time_series_chart_payload, event_validator_processing_time_payload]
headers = {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ' + jwt_token
}
for payload in payloads:
    response = requests.post(create_chart_url, headers=headers, data=payload)
    if response.status_code == 201:
        print("Chart created successfully." + payload)
    else:
        print("Failed to create chart. Status code:", response.status_code)
