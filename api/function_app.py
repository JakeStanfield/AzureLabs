import azure.functions as func
import logging
import os
import json
from azure.cosmos import CosmosClient, exceptions

app = func.FunctionApp()

# Cosmos DB configuration
COSMOS_ENDPOINT = os.environ.get('COSMOS_ENDPOINT')
COSMOS_KEY = os.environ.get('COSMOS_KEY')
DATABASE_NAME = 'resumeDB'
CONTAINER_NAME = 'counter'
ITEM_ID = 'visitor-count'

# Initialize Cosmos client
client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
database = client.get_database_client(DATABASE_NAME)
container = database.get_container_client(CONTAINER_NAME)


def get_and_increment_count():
    try:
        item = container.read_item(item=ITEM_ID, partition_key=ITEM_ID)
        current_count = item.get('count', 0)
        new_count = current_count + 1
        item['count'] = new_count
        container.upsert_item(item)
        logging.info(f'Visitor count updated to: {new_count}')
        return new_count
    except exceptions.CosmosResourceNotFoundError:
        logging.info('Counter not found, creating new one')
        item = {'id': ITEM_ID, 'count': 1}
        container.create_item(item)
        return 1
    except Exception as e:
        logging.error(f'Error updating count: {str(e)}')
        raise


@app.function_name(name="GetVisitorCount")
@app.route(route="GetVisitorCount", methods=["GET", "POST", "OPTIONS"])
def get_visitor_count(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Visitor counter function triggered')
    
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    }
    
    if req.method == 'OPTIONS':
        return func.HttpResponse(body='', status_code=200, headers=headers)
    
    try:
        new_count = get_and_increment_count()
        response_body = json.dumps({'count': new_count})
        return func.HttpResponse(body=response_body, status_code=200, headers=headers)
    except Exception as e:
        logging.error(f'Function error: {str(e)}')
        error_body = json.dumps({'error': 'Failed to update visitor count', 'message': str(e)})
        return func.HttpResponse(body=error_body, status_code=500, headers=headers)