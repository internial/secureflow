import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 spike load test – 100 VUs, reused across two environments:
//
//   Phase 1 (Docker Compose): validates application behaviour under spike load
//     → verify: request rate, CPU/memory usage, p95 latency, error rate
//
//   Phase 2 (Kind Kubernetes): validates Kubernetes behaviour under the same load
//     → verify: all of the above PLUS pod replica count and HPA scaling activity
//
export const options = {
  stages: [
    { duration: '30s', target: 100 }, // Ramp up to 100 VUs over 30 seconds
    { duration: '60s', target: 100 }, // Hold 100 VUs for 60 seconds (triggers HPA in Kind)
    { duration: '30s', target: 0 },   // Ramp down to 0 VUs over 30 seconds
  ],
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost/api/users';

export default function () {
  const headers = { 'Content-Type': 'application/json' };
  
  // Continuous REST CRUD operations to generate load
  const email = `sre-spike-${Math.floor(Math.random() * 1000000)}@secureflow.local`;
  const postPayload = JSON.stringify({
    name: 'Spike Tester',
    email: email
  });
  
  const postRes = http.post(BASE_URL, postPayload, { headers });
  const postOk = check(postRes, {
    'POST status is 201': (r) => r.status === 201,
  });
  
  if (postOk && postRes.body) {
    const userId = JSON.parse(postRes.body).id;
    const userUrl = `${BASE_URL}/${userId}`;

    // Random sleep between 100ms and 500ms to simulate rapid user action spikes
    sleep(Math.random() * 0.4 + 0.1);

    const getRes = http.get(userUrl);
    check(getRes, {
      'GET status is 200': (r) => r.status === 200,
    });
    
    sleep(Math.random() * 0.4 + 0.1);

    const deleteRes = http.del(userUrl);
    check(deleteRes, {
      'DELETE status is 204': (r) => r.status === 204,
    });
  }
  
  sleep(0.5);
}
