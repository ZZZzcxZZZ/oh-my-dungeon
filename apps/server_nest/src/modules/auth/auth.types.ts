export interface RegisterInput {
  username: string;
  email: string;
  password: string;
}

export interface RegisteredUser {
  id: string;
  username: string;
  email: string;
}

export interface RegisterResult {
  user: RegisteredUser;
  isFirstUser: boolean;
}

export interface LoginInput {
  identifier: string;
  password: string;
}

export interface AccessTokenPayload {
  userId: string;
  username: string;
}

export interface LoginResult {
  user: RegisteredUser;
  accessToken: string;
  refreshToken: string;
}

export interface RefreshResult {
  accessToken: string;
}
