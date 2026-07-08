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
