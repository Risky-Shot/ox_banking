import { AccountRole } from './nui';

type AccountType = 'personal' | 'shared' | 'group';

export interface Character {
  cash: number;
}

export interface Account {
  id: number;
  label: string;
  owner?: string;
  group?: string;
  balance: number;
  isDefault?: boolean;
  type: AccountType;
  role: AccountRole;
}

export type DatabaseAccount = {
  id: number;
  balance: number;
  isDefault?: boolean;
  label: string;
  owner?: number;
  group?: string;
  type: AccountType;
};

export type OxAccountRole = 'viewer' | 'contributor' | 'manager' | 'owner';

export interface OxAccountPermissions {
  deposit: boolean;
  withdraw: boolean;
  addUser: boolean;
  removeUser: boolean;
  manageUser: boolean;
  transferOwnership: boolean;
  viewHistory: boolean;
  manageAccount: boolean;
  closeAccount: boolean;
  sendInvoice: boolean;
  payInvoice: boolean;
}