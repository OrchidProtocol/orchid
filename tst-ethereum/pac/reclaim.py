import json
import logging
import os

from recycle import main as recycle
from utils import configure_logging, get_secret
from w3 import keys


configure_logging(level="DEBUG")


def main(event, context):
    logging.debug('Beginning Account Reclaiming Process')
    pac_funder = get_secret(key=os.environ['PAC_FUNDER_PUBKEY_SECRET'])
    logging.debug(f'Funder: {pac_funder}')
    signers = keys(funder=pac_funder)
    context = None
    body = {
        'debug': 'True',
        'funder': pac_funder,
    }
    for signer in signers:
        logging.debug(f'Processing Signer: {signer}')
        body['signer'] = signer
        event = {
            'body': json.dumps(body),
        }
        recycle(event, context)
