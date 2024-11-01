import React from 'react';
import UnpaidInvoiceItem from './UnpaidInvoiceItem';
import { UnpaidInvoice } from '../../../../../../typings';

const UnpaidInvoicesContainer: React.FC<{ invoices: UnpaidInvoice[] }> = ({ invoices }) => {
  return (
    <div className="flex flex-col gap-2">
      {invoices.map((invoice) => (
        <UnpaidInvoiceItem key={invoice.id} invoice={invoice} />
      ))}
    </div>
  );
};

export default UnpaidInvoicesContainer;
