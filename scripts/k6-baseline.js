import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 baseline load test configuration
export const options = {
  vus: 10,
  duration: '5m',
  thresholds: {
    // p95 latency must be under 300ms
    http_req_duration: ['p(95)<300'],
    // request error rate must be under 1%
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost/api/users';

export default function () {
  const headers = { 'Content-Type': 'application/json' };
  
  // 1. POST - Create User
  const email = `sre-test-${Math.floor(Math.random() * 1000000)}@secureflow.local`;
  const postPayload = JSON.stringify({
    name: 'SRE Tester',
    email: email
  });
  
  const postRes = http.post(BASE_URL, postPayload, { headers });
  const postOk = check(postRes, {
    'POST status is 201': (r) => r.status === 201,
    'POST returns user ID': (r) => JSON.parse(r.body).id !== undefined,
  });
  
  sleep(1);

  if (postOk && postRes.body) {
    const userId = JSON.parse(postRes.body).id;
    const userUrl = `${BASE_URL}/${userId}`;

    // 2. GET - Retrieve User
    const getRes = http.get(userUrl);
    check(getRes, {
      'GET status is 200': (r) => r.status === 200,
      'GET has correct email': (r) => JSON.parse(r.body).email === email,
    });
    
    sleep(1);

    // 3. PUT - Update User
    const putPayload = JSON.stringify({
      name: 'Updated SRE Tester',
      email: email
    });
    const putRes = http.put(userUrl, putPayload, { headers });
    check(putRes, {
      'PUT status is 200': (r) => r.status === 200,
      'PUT has updated name': (r) => JSON.parse(r.body).name === 'Updated SRE Tester',
    });
    
    sleep(1);

    // 4. DELETE - Delete User
    const deleteRes = http.del(userUrl);
    check(deleteRes, {
      'DELETE status is 204': (r) => r.status === 204,
    });
  }
  
  sleep(1);
}
