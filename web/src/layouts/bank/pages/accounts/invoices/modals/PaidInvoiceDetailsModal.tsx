import locales from '../../../../../../locales';
import { formatDate } from '../../../../../../utils/formatDate';
import { formatNumber } from '../../../../../../utils/formatNumber';
import React from 'react';
import { PaidInvoice } from '../../../../../../typings';

const PaidInvoiceDetailsModal: React.FC<{ invoice: PaidInvoice }> = ({ invoice }) => {
  return (
    <div className="flex flex-col gap-4">
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_payment_to}</p>
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
        <p className="text-sm">{formatDate(invoice.dueDate)}</p>
      </div>
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_details_paid_at}</p>
        <p className="text-sm">{formatDate(invoice.paidAt)}</p>
      </div>
      <div>
        <p className="text-muted-foreground text-xs">{locales.invoice_details_paid_by}</p>
        <p className="text-sm">{invoice.paidBy}</p>
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

export default PaidInvoiceDetailsModal;
