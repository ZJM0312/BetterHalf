/**
 * API client for BetterHalf backend
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api/v1';

interface ApiError {
  code: string;
  message: string;
  requestId: string;
  timestamp: string;
  details?: Record<string, string>;
}

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const defaultHeaders: HeadersInit = {
      'Content-Type': 'application/json',
    };

    const response = await fetch(url, {
      ...options,
      headers: {
        ...defaultHeaders,
        ...options.headers,
      },
      credentials: 'include', // Include cookies for auth
    });

    if (!response.ok) {
      const error: ApiError = await response.json().catch(() => ({
        code: 'UNKNOWN_ERROR',
        message: response.statusText,
        requestId: '',
        timestamp: new Date().toISOString(),
      }));
      throw new ApiRequestError(error, response.status);
    }

    // Handle empty responses (204 No Content)
    if (response.status === 204) {
      return {} as T;
    }

    return response.json();
  }

  // Auth endpoints
  async register(data: { email: string; password: string; name: string }) {
    return this.request<AuthResponse>('/auth/register', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async login(data: { email: string; password: string }) {
    return this.request<AuthResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async refresh() {
    return this.request<{ accessToken: string }>('/auth/refresh', {
      method: 'POST',
    });
  }

  async logout() {
    return this.request<void>('/auth/logout', {
      method: 'POST',
    });
  }

  async getMe() {
    return this.request<UserResponse>('/auth/me');
  }

  // Couple endpoints
  async createCouple(data: { name: string; visibility?: string }) {
    return this.request<CoupleResponse>('/couples', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getCouple(coupleId: string) {
    return this.request<CoupleResponse>(`/couples/${coupleId}`);
  }

  async getMyCouples() {
    return this.request<CoupleResponse[]>('/couples/me');
  }

  // Event endpoints
  async createEvent(coupleId: string, data: {
    title?: string;
    description?: string;
    eventDate?: string;
    visibility?: string;
  }) {
    return this.request<EventResponse>(`/couples/${coupleId}/events`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getEvents(coupleId: string, cursor?: string, limit?: number) {
    const params = new URLSearchParams();
    if (cursor) params.set('cursor', cursor);
    if (limit) params.set('limit', limit.toString());
    const query = params.toString() ? `?${params.toString()}` : '';
    
    return this.request<PageResult<EventResponse>>(`/couples/${coupleId}/events${query}`);
  }

  async getEvent(coupleId: string, eventId: string) {
    return this.request<EventResponse>(`/couples/${coupleId}/events/${eventId}`);
  }

  async deleteEvent(coupleId: string, eventId: string) {
    return this.request<void>(`/couples/${coupleId}/events/${eventId}`, {
      method: 'DELETE',
    });
  }

  // Media endpoints
  async initUpload(coupleId: string, data: { contentType: string; fileSize: number }) {
    return this.request<UploadInitResponse>(`/couples/${coupleId}/media/upload-init`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async completeUpload(coupleId: string, mediaId: string, data: {
    width?: number;
    height?: number;
    durationSeconds?: number;
  }) {
    return this.request<MediaResponse>(`/couples/${coupleId}/media/${mediaId}/upload-complete`, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getMediaUrl(coupleId: string, mediaId: string) {
    return this.request<{ url: string }>(`/couples/${coupleId}/media/${mediaId}/url`);
  }

  // Health check
  async healthCheck() {
    const response = await fetch(`${this.baseUrl.replace('/api/v1', '')}/actuator/health`);
    return response.json();
  }
}

// Error class
export class ApiRequestError extends Error {
  public code: string;
  public requestId: string;
  public status: number;
  public details?: Record<string, string>;

  constructor(error: ApiError, status: number) {
    super(error.message);
    this.code = error.code;
    this.requestId = error.requestId;
    this.status = status;
    this.details = error.details;
    this.name = 'ApiRequestError';
  }
}

// Types
export interface AuthResponse {
  id: string;
  email: string;
  name: string;
  accessToken: string;
}

export interface UserResponse {
  id: string;
  email: string;
  name: string;
  emailVerified: boolean;
}

export interface CoupleResponse {
  id: string;
  name: string;
  visibility: string;
  createdAt: string;
  updatedAt: string;
}

export interface EventResponse {
  id: string;
  coupleId: string;
  createdBy: string;
  title: string;
  description: string;
  eventDate: string;
  visibility: string;
  createdAt: string;
  updatedAt: string;
}

export interface MediaResponse {
  id: string;
  coupleId: string;
  uploadedBy: string;
  contentType: string;
  fileSize: number;
  width?: number;
  height?: number;
  durationSeconds?: number;
  visibility: string;
  processingStatus: string;
  createdAt: string;
}

export interface UploadInitResponse {
  mediaId: string;
  uploadUrl: string;
  storageKey: string;
}

export interface PageResult<T> {
  items: T[];
  nextCursor?: string;
  hasMore: boolean;
}

// Singleton instance
export const api = new ApiClient();
export default api;
