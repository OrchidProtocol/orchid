import asyncio
import random
import datetime
import json
import requests

import websockets

class jobs:
    def __init__(self, model, url):
        self.queue = asyncio.PriorityQueue()
        self.sessions = {}
        self.model = model
        self.url = url

    def get_queues(self, id):
        squeue = asyncio.Queue(maxsize=10)
        rqueue = asyncio.Queue(maxsize=10)
        self.sessions[id] = {'send': squeue, 'recv': rqueue}
        return [rqueue, squeue]

    async def add_job(self, id, bid, job):
        print(f'add_job({id}, {bid}, {job})')
        priority = 0.1
        await self.queue.put((priority, [id, bid, job]))
        
    async def process_jobs(self):
        while True:
            priority, job_params = await self.queue.get()
            print(f"process_jobs: got job: {job_params}")
            id, bid, job = job_params
            await self.sessions[id]['send'].put(json.dumps({'type': 'started'}))
            result = ""
            data = {'model': self.model, "temperature": 0.7, "top_p": 1, 
                    "max_tokens": 4000, "stream": False, "safe_prompt": False, "random_seed": None, 
                    'messages': [{'role': 'user', 'content': job['prompt']}]}
            r = requests.post(self.url, data=json.dumps(data))
            result = r.json()
            print(result)
            if result['object'] != 'chat.completion':
              print('*** Error from llm')
              continue
            response = result['choices'][0]['message']['content']
            model = result['model']
            reason = result['choices'][0]['finish_reason']
            usage = result['usage']
            await self.sessions[id]['send'].put(json.dumps({'type': 'complete', 'response': response,
                                                            'model': model, 'reason': reason,
                                                            'usage': usage}))
                