import ConnectWallet from '@/components/ConnectWallet';
import Menu from '@/components/global/Menu';
import Logo from '@/components/ui/Logo';
import {
  useDynamicContext,
} from '@dynamic-labs/sdk-react-core'
import Link from 'next/link';



const Header = () => {
  const {  isAuthenticated } = useDynamicContext();

  return (
  <div className=' px-5 lg:px-20 py-12 border-b border-white flex justify-between items-center'>
      <Link href="/">
      <Logo/>
      </Link>
      <Menu  menuPoints={['about us', 'how it works']} />
      <div className='flex flex-row items-baseline gap-x-5'>
     
      { isAuthenticated ? <Link href="/account" >my bounties</Link> : null}

      <ConnectWallet/>

      </div>
  </div>
  );
};

export default Header;