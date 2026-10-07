import React, { useEffect, useState } from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ShieldAlert, ShieldCheck, UserCog, UserCheck, Calendar } from 'lucide-react';
import { getUsers, updateUserStatus, User } from '@/api';
import { maskPhone } from '@/lib/utils';
import UserChatSessionsDialog from '@/components/UserChatSessionsDialog';

const Users = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Dialog State
  const [isSessionsDialogOpen, setIsSessionsDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<{id: number, name: string} | null>(null);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const data = await getUsers();
      setUsers(data);
    } catch (error) {
      console.error('Failed to fetch users:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleToggleStatus = async (user: User) => {
    if (user.is_admin) {
      alert('无法禁用管理员账号');
      return;
    }
    if (user.is_deactivated) {
      alert('该账号已注销，不可解封');
      return;
    }

    const action = user.is_active ? '封禁' : '解封';
    if (window.confirm(`确定要${action}用户 ${user.display_name} (${maskPhone(user.phone)}) 吗？`)) {
      try {
        await updateUserStatus(user.id, !user.is_active);
        setUsers(users.map(u => u.id === user.id ? { ...u, is_active: !user.is_active } : u));
      } catch (error) {
        console.error('Failed to update user status:', error);
        alert(`操作失败，请重试`);
      }
    }
  };

  const handleOpenSessions = (user: User) => {
    if (user.session_count > 0) {
      setSelectedUser({ id: user.id, name: user.display_name || user.phone });
      setIsSessionsDialogOpen(true);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center bg-white p-6 rounded-xl shadow-sm border border-slate-100">
        <div>
          <h2 className="text-2xl font-bold text-slate-800">用户管理</h2>
          <p className="text-slate-500 mt-1 text-sm">查看注册用户列表、就诊档案及历史会话数，并对违规账号进行管控。</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
        <Table>
          <TableHeader className="bg-slate-50/80">
            <TableRow>
              <TableHead className="w-[80px]">ID</TableHead>
              <TableHead className="w-[180px]">用户信息</TableHead>
              <TableHead>手机号</TableHead>
              <TableHead>账号状态</TableHead>
              <TableHead>就诊档案数</TableHead>
              <TableHead>历史会话数</TableHead>
              <TableHead className="text-right">操作</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  <div className="flex items-center justify-center space-x-2 animate-pulse">
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full"></div>
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full" style={{ animationDelay: '200ms' }}></div>
                    <div className="w-2 h-2 bg-[#6C63FF] rounded-full" style={{ animationDelay: '400ms' }}></div>
                    <span>加载用户列表中...</span>
                  </div>
                </TableCell>
              </TableRow>
            ) : users.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="h-32 text-center text-slate-500">
                  暂无注册用户
                </TableCell>
              </TableRow>
            ) : (
              users.map((user) => (
                <TableRow key={user.id} className="group">
                  <TableCell className="font-medium text-slate-600">#{user.id}</TableCell>
                  <TableCell>
                    <div className="flex items-center">
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold mr-3 ${
                        user.is_admin ? 'bg-orange-100 text-orange-600' : 'bg-slate-100 text-slate-600'
                      }`}>
                        {user.is_admin ? <UserCog size={16} /> : <UserCheck size={16} />}
                      </div>
                      <div className="flex flex-col">
                        <span className="font-medium text-slate-900 flex items-center">
                          {user.display_name}
                          {user.is_admin && <Badge variant="outline" className="ml-2 text-[10px] h-5 border-orange-200 text-orange-600 bg-orange-50">管理员</Badge>}
                        </span>
                        <span className="text-xs text-slate-400 mt-0.5 flex items-center">
                          <Calendar size={12} className="mr-1" />
                          {new Date(user.created_at).toLocaleDateString()}
                        </span>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <span className="font-mono text-slate-600 bg-slate-50 px-2 py-1 rounded border border-slate-100">{maskPhone(user.phone)}</span>
                  </TableCell>
                  <TableCell>
                    {user.is_deactivated ? (
                      <Badge className="bg-slate-100 text-slate-500 hover:bg-slate-100 border-0">已注销</Badge>
                    ) : user.is_active ? (
                      <Badge className="bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border-0">正常</Badge>
                    ) : (
                      <Badge className="bg-red-50 text-red-700 hover:bg-red-100 border-0">已封禁</Badge>
                    )}
                  </TableCell>
                  <TableCell>
                    <span className="text-slate-600 font-medium">{user.profile_count}</span> <span className="text-slate-400 text-sm">份</span>
                  </TableCell>
                  <TableCell>
                    <button 
                      onClick={() => handleOpenSessions(user)}
                      disabled={user.session_count === 0}
                      className={`group/btn flex items-center space-x-1 font-medium ${
                        user.session_count > 0 
                          ? 'text-[#6C63FF] hover:underline cursor-pointer' 
                          : 'text-slate-600 cursor-default'
                      }`}
                      title={user.session_count > 0 ? "点击查看历史咨询" : ""}
                    >
                      <span className="text-lg">{user.session_count}</span> 
                      <span className="text-sm font-normal text-slate-400 group-hover/btn:text-[#6C63FF]">次</span>
                    </button>
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex items-center justify-end space-x-2 opacity-80 group-hover:opacity-100 transition-opacity">
                      {!user.is_admin && !user.is_deactivated && (
                        <Button 
                          variant={user.is_active ? "outline" : "default"} 
                          size="sm" 
                          onClick={() => handleToggleStatus(user)} 
                          className={`h-8 ${user.is_active ? 'border-red-200 text-red-600 hover:bg-red-50 hover:text-red-700' : 'bg-emerald-500 hover:bg-emerald-600 text-white'}`}
                        >
                          {user.is_active ? (
                            <><ShieldAlert className="w-3.5 h-3.5 mr-1" /> 封禁</>
                          ) : (
                            <><ShieldCheck className="w-3.5 h-3.5 mr-1" /> 解封</>
                          )}
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* User Chat Sessions Dialog */}
      {selectedUser && (
        <UserChatSessionsDialog
          isOpen={isSessionsDialogOpen}
          onOpenChange={setIsSessionsDialogOpen}
          userId={selectedUser.id}
          userName={selectedUser.name}
        />
      )}
    </div>
  );
};

export default Users;