const request = require('supertest');
const app = require('../src/index');

describe('GET /', () => {
  it('should return API running message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('DevOps API is running!');
  });
});

describe('GET /health', () => {
  it('should return status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('POST /echo', () => {
  it('should return the request body', async () => {
    const res = await request(app)
      .post('/echo')
      .send({ name: 'vikas' });
    expect(res.statusCode).toBe(200);
    expect(res.body.received).toEqual({ name: 'vikas' });
  });

  it('should return 400 if body is empty', async () => {
    const res = await request(app).post('/echo').send({});
    expect(res.statusCode).toBe(400);
  });
});