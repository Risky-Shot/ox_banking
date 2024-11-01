import NavItem from '../../../layouts/bank/components/NavItem';
import NavLink from '../../../layouts/bank/components/NavLink';
import ThemeSwitcher from '../../../layouts/bank/components/ThemeSwitcher';
import locales from '../../../locales';
import { useSetBankVisibility } from '../../../state/visibility';
import { fetchNui } from '../../../utils/fetchNui';
import { CreditCard, LayoutDashboard, LogOut } from 'lucide-react';
import React from 'react';

const Navbar: React.FC = () => {
  const setBankVisibility = useSetBankVisibility();

  return (
    <nav className="flex shrink-0 flex-col items-center justify-between rounded-bl-lg rounded-tl-lg bg-card p-2">
      <div className="flex flex-col items-center justify-center">
        <NavLink icon={LayoutDashboard} label={locales.dashboard} path="/" />
        <NavLink icon={CreditCard} label={locales.accounts} path="/accounts" />
      </div>

      <div className="flex flex-col items-center justify-center">
        <ThemeSwitcher />
        <NavItem
          exit
          label={locales.exit}
          icon={LogOut}
          onClick={() => {
            setBankVisibility(false);
            fetchNui('exit');
          }}
        />
      </div>
    </nav>
  );
};

export default Navbar;
