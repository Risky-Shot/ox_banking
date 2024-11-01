import locales from '../../../../../../locales';
import { formatDate } from '../../../../../../utils/formatDate';
import { formatNumber } from '../../../../../../utils/formatNumber';
import React from 'react';
import { UnpaidInvoice } from '../../../../../../typings';

const UnpaidInvoiceDetailsModal: React.FC<{ invoice: UnpaidInvoice }> = ({ invoice }) => {
  return (
    <div className="flex flex-col gap-4">
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_details_sent_to}</p>
        <p className="text-sm">{invoice.label}</p>
      </div>
      {invoice.sentBy && (
        <div>
          <p className="text-muted-foreground text-xs">{locales.invoice_details_sent_by}</p>
          <p className="text-sm">{invoice.sentBy}</p>
        </div>
      )}
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_details_sent_at}</p>
        <p className="text-sm">{formatDate(invoice.sentAt)}</p>
      </div>
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_details_due_by}</p>
        <p>{formatDate(invoice.dueDate)}</p>
      </div>
      <div>
        <p className="text-muted-foreground text-xs">{locales.message}</p>
        <p className="text-sm">{invoice.message}</p>
      </div>
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_total}</p>
        <p className="text-sm">{formatNumber(invoice.amount)}</p>
      </div>
    </div>
  );
};

export default UnpaidInvoiceDetailsModal;
