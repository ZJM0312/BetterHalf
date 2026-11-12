'use client';

import { useState } from 'react';
import api, { ApiRequestError, AuthResponse, CoupleResponse, EventResponse } from '@/lib/api';

interface TestResult {
  name: string;
  status: 'pending' | 'success' | 'error';
  message?: string;
  data?: unknown;
}

export default function TestPage() {
  const [results, setResults] = useState<TestResult[]>([]);
  const [isRunning, setIsRunning] = useState(false);
  const [user, setUser] = useState<AuthResponse | null>(null);
  const [couple, setCouple] = useState<CoupleResponse | null>(null);

  const addResult = (result: TestResult) => {
    setResults(prev => [...prev, result]);
  };

  const updateResult = (name: string, update: Partial<TestResult>) => {
    setResults(prev => prev.map(r => r.name === name ? { ...r, ...update } : r));
  };

  const runTests = async () => {
    setIsRunning(true);
    setResults([]);
    setUser(null);
    setCouple(null);

    const testEmail = `test${Date.now()}@example.com`;
    const testPassword = 'TestPassword123!';

    // Test 1: Health Check
    addResult({ name: 'Health Check', status: 'pending' });
    try {
      const health = await api.healthCheck();
      updateResult('Health Check', { 
        status: 'success', 
        message: `Backend is ${health.status}`,
        data: health 
      });
    } catch (error) {
      updateResult('Health Check', { 
        status: 'error', 
        message: error instanceof Error ? error.message : 'Failed to connect to backend' 
      });
      setIsRunning(false);
      return; // Stop if health check fails
    }

    // Test 2: Register
    addResult({ name: 'Register User', status: 'pending' });
    try {
      const authResult = await api.register({
        email: testEmail,
        password: testPassword,
        name: 'Test User',
      });
      setUser(authResult);
      updateResult('Register User', { 
        status: 'success', 
        message: `Registered as ${authResult.email}`,
        data: authResult 
      });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to register';
      updateResult('Register User', { status: 'error', message });
      setIsRunning(false);
      return;
    }

    // Test 3: Get Current User
    addResult({ name: 'Get Current User', status: 'pending' });
    try {
      const me = await api.getMe();
      updateResult('Get Current User', { 
        status: 'success', 
        message: `Retrieved user: ${me.email}`,
        data: me 
      });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to get user';
      updateResult('Get Current User', { status: 'error', message });
    }

    // Test 4: Create Couple
    addResult({ name: 'Create Couple', status: 'pending' });
    try {
      const coupleResult = await api.createCouple({
        name: 'Test Couple',
        visibility: 'PRIVATE',
      });
      setCouple(coupleResult);
      updateResult('Create Couple', { 
        status: 'success', 
        message: `Created couple: ${coupleResult.name}`,
        data: coupleResult 
      });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to create couple';
      updateResult('Create Couple', { status: 'error', message });
      setIsRunning(false);
      return;
    }

    // Test 5: Get My Couples
    addResult({ name: 'Get My Couples', status: 'pending' });
    try {
      const couples = await api.getMyCouples();
      updateResult('Get My Couples', { 
        status: 'success', 
        message: `Found ${couples.length} couple(s)`,
        data: couples 
      });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to get couples';
      updateResult('Get My Couples', { status: 'error', message });
    }

    // Test 6: Create Event
    if (couple) {
      addResult({ name: 'Create Event', status: 'pending' });
      try {
        const event = await api.createEvent(couple.id, {
          title: 'First Date',
          description: 'Our first date together',
          eventDate: '2024-01-15',
          visibility: 'INHERIT',
        });
        updateResult('Create Event', { 
          status: 'success', 
          message: `Created event: ${event.title}`,
          data: event 
        });

        // Test 7: Get Events
        addResult({ name: 'Get Events', status: 'pending' });
        try {
          const events = await api.getEvents(couple.id);
          updateResult('Get Events', { 
            status: 'success', 
            message: `Found ${events.items.length} event(s)`,
            data: events 
          });
        } catch (error) {
          const message = error instanceof ApiRequestError 
            ? `${error.code}: ${error.message}` 
            : 'Failed to get events';
          updateResult('Get Events', { status: 'error', message });
        }

        // Test 8: Delete Event
        addResult({ name: 'Delete Event', status: 'pending' });
        try {
          await api.deleteEvent(couple.id, event.id);
          updateResult('Delete Event', { 
            status: 'success', 
            message: 'Event deleted successfully' 
          });
        } catch (error) {
          const message = error instanceof ApiRequestError 
            ? `${error.code}: ${error.message}` 
            : 'Failed to delete event';
          updateResult('Delete Event', { status: 'error', message });
        }
      } catch (error) {
        const message = error instanceof ApiRequestError 
          ? `${error.code}: ${error.message}` 
          : 'Failed to create event';
        updateResult('Create Event', { status: 'error', message });
      }
    }

    // Test 9: Logout
    addResult({ name: 'Logout', status: 'pending' });
    try {
      await api.logout();
      updateResult('Logout', { status: 'success', message: 'Logged out successfully' });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to logout';
      updateResult('Logout', { status: 'error', message });
    }

    // Test 10: Login
    addResult({ name: 'Login', status: 'pending' });
    try {
      const loginResult = await api.login({
        email: testEmail,
        password: testPassword,
      });
      updateResult('Login', { 
        status: 'success', 
        message: `Logged in as ${loginResult.email}`,
        data: loginResult 
      });
    } catch (error) {
      const message = error instanceof ApiRequestError 
        ? `${error.code}: ${error.message}` 
        : 'Failed to login';
      updateResult('Login', { status: 'error', message });
    }

    setIsRunning(false);
  };

  const successCount = results.filter(r => r.status === 'success').length;
  const errorCount = results.filter(r => r.status === 'error').length;

  return (
    <div style={{ padding: '2rem', maxWidth: '800px', margin: '0 auto', fontFamily: 'system-ui' }}>
      <h1 style={{ marginBottom: '1rem' }}>🧪 BetterHalf API 测试</h1>
      
      <div style={{ marginBottom: '2rem' }}>
        <p style={{ color: '#666', marginBottom: '1rem' }}>
          此页面测试前后端连接和核心 API 功能。
        </p>
        <button 
          onClick={runTests} 
          disabled={isRunning}
          style={{
            padding: '0.75rem 1.5rem',
            fontSize: '1rem',
            backgroundColor: isRunning ? '#ccc' : '#0070f3',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: isRunning ? 'not-allowed' : 'pointer',
          }}
        >
          {isRunning ? '运行中...' : '运行测试'}
        </button>
      </div>

      {results.length > 0 && (
        <>
          <div style={{ 
            marginBottom: '1rem', 
            padding: '1rem', 
            backgroundColor: '#f5f5f5', 
            borderRadius: '8px' 
          }}>
            <strong>测试结果: </strong>
            <span style={{ color: 'green' }}>✓ {successCount} 成功</span>
            {' | '}
            <span style={{ color: 'red' }}>✗ {errorCount} 失败</span>
            {' | '}
            <span style={{ color: '#999' }}>{results.length} 总计</span>
          </div>

          <div>
            {results.map((result, index) => (
              <div 
                key={index}
                style={{
                  padding: '1rem',
                  marginBottom: '0.5rem',
                  backgroundColor: result.status === 'success' ? '#e6f7e6' 
                    : result.status === 'error' ? '#ffe6e6' 
                    : '#fff3cd',
                  borderRadius: '8px',
                  border: `1px solid ${
                    result.status === 'success' ? '#b8e6b8' 
                    : result.status === 'error' ? '#ffb3b3' 
                    : '#ffc107'
                  }`,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span>
                    {result.status === 'success' ? '✓' 
                      : result.status === 'error' ? '✗' 
                      : '⏳'}
                  </span>
                  <strong>{result.name}</strong>
                </div>
                {result.message && (
                  <div style={{ marginTop: '0.5rem', fontSize: '0.9rem', color: '#666' }}>
                    {result.message}
                  </div>
                )}
                {result.data != null && (
                  <details style={{ marginTop: '0.5rem' }}>
                    <summary style={{ cursor: 'pointer', fontSize: '0.85rem', color: '#888' }}>
                      查看响应数据
                    </summary>
                    <pre style={{ 
                      marginTop: '0.5rem', 
                      padding: '0.5rem', 
                      backgroundColor: '#f0f0f0', 
                      borderRadius: '4px',
                      fontSize: '0.8rem',
                      overflow: 'auto'
                    }}>
                      {JSON.stringify(result.data, null, 2)}
                    </pre>
                  </details>
                )}
              </div>
            ))}
          </div>
        </>
      )}

      <div style={{ marginTop: '2rem', padding: '1rem', backgroundColor: '#f0f8ff', borderRadius: '8px' }}>
        <h3>📋 测试前准备</h3>
        <ol style={{ lineHeight: '1.8', color: '#333' }}>
          <li>确保 PostgreSQL 运行中 (端口 5432)</li>
          <li>确保 Redis 运行中 (端口 6379)</li>
          <li>启动后端: <code>cd backend && ./mvnw spring-boot:run -pl betterhalf-api</code></li>
          <li>启动前端: <code>cd frontend && npm run dev</code></li>
          <li>访问此页面: <a href="http://localhost:3000/test">http://localhost:3000/test</a></li>
        </ol>
      </div>
    </div>
  );
}
