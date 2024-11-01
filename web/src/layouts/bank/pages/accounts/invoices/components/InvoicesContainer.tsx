import Pagination from '../../../../../../layouts/bank/components/Pagination';
import { queryClient } from '../../../../../../main';
import {
  useDebouncedInvoicesFilters,
  useInvoicesFilters,
  useIsInvoicesFiltersDebouncing,
  useSetInvoicesFiltersDebounce,
} from '../../../../../../state/accounts/invoices';
import { fetchNui } from '../../../../../../utils/fetchNui';
import { useQuery } from '@tanstack/react-query';
import React from 'react';
import { PaidInvoice, SentInvoice, UnpaidInvoice } from '../../../../../../typings';
import PaidInvoicesContainer from './PaidInvoicesContainer';
import SentInvoicesContainer from './SentInvoicesContainer';
import SkeletonInvoices from './SkeletonInvoices';
import UnpaidInvoicesContainer from './UnpaidInvoicesContainer';

const InvoicesContainer: React.FC<{ accountId: number }> = ({ accountId }) => {
  const debouncedFilters = useDebouncedInvoicesFilters();
  const filters = useInvoicesFilters();
  const setFilters = useSetInvoicesFiltersDebounce();
  const isDebouncing = useIsInvoicesFiltersDebouncing();

  const [maxPages, setMaxPages] = React.useState(0);

  const query = useQuery<{ invoices: Array<UnpaidInvoice | PaidInvoice | SentInvoice>; numberOfPages: number }>(
    {
      queryKey: ['invoices', accountId, debouncedFilters],
      gcTime: 0,
      staleTime: 0,
      queryFn: async () => {
        const data = await fetchNui<{
          invoices: Array<UnpaidInvoice | PaidInvoice | SentInvoice>;
          numberOfPages: number;
        }>(
          'getInvoices',
          { accountId, filters: debouncedFilters },
          {
            data: {
              numberOfPages: 1,
              invoices: [
                {
                  id: 0,
                  type: 'unpaid',
                  label: 'SomeOtherAccount LLC',
                  message: 'Bill',
                  amount: 3000,
                  dueDate: Date.now(),
                  sentAt: Date.now(),
                },
                {
                  id: 1,
                  type: 'unpaid',
                  label: 'SomeOtherAccount LLC',
                  message: 'Bill',
                  amount: 3000,
                  dueDate: Date.now(),
                  sentAt: Date.now(),
                },
              ] satisfies UnpaidInvoice[],
            },
            delay: 3000,
          }
        );

        setMaxPages(data.numberOfPages);

        return data;
      },
    },
    queryClient
  );

  return (
    <div className="flex h-full flex-col justify-between">
      {query.isLoading || isDebouncing ? (
        <SkeletonInvoices />
      ) : (
        <>
          {filters.type === 'unpaid' && <UnpaidInvoicesContainer invoices={query.data!.invoices as UnpaidInvoice[]} />}
          {filters.type === 'paid' && <PaidInvoicesContainer invoices={query.data!.invoices as PaidInvoice[]} />}
          {filters.type === 'sent' && <SentInvoicesContainer invoices={query.data!.invoices as SentInvoice[]} />}
        </>
      )}
      <Pagination
        maxPages={maxPages}
        page={filters.page}
        setPage={(page) => setFilters((prev : any) => ({ ...prev, page }))}
      />
    </div>
  );
};

export default InvoicesContainer;
