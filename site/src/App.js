import './App.css';
import arcs from './arcs.json';

import React, { useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import ReactMarkdown from 'react-markdown';

import { Card, Layout, Table, Tag } from 'antd';
const { Header, Content, Footer } = Layout;

const Readme = ({ readme }) => {
    const ref = useRef(null);

    useEffect(() => {
        if (readme && ref) {
            ReactDOM.render(<ReactMarkdown source={readme} />, ref.current)
        }
    }, [readme])

    return <div ref={ref} />
}

function App() {
    const rows = Object.values(arcs).map(proposal => {
        const { arc, title, authors, topic, status } = proposal.metadata;
        return { key: arc, arc, title, authors, topic, status }
    });

    const columns = [
        {
            title: 'ARC',
            dataIndex: 'arc',
            key: 'arc',
            sorter: true,
            render: arc => <a onClick={proposal.bind(this, arc)}>{arc}</a>,
        },
        {
            title: 'Title',
            dataIndex: 'title',
            key: 'title',
        },
        {
            title: 'Authors',
            dataIndex: 'authors',
            key: 'authors',
        },
        {
            title: 'Topic',
            dataIndex: 'topic',
            key: 'topic',
            sorter: true,
            render: topic => {
                let tag = topic.toLowerCase();
                let color = 'green';
                if (tag === 'protocol') {
                    color = 'blue';
                } else if (tag === 'network') {
                    color = 'purple';
                } else if (tag === 'application') {
                    color = 'magenta';
                }
                return (
                    <Tag color={color} key={tag}>
                        {tag.toUpperCase()}
                    </Tag>
                );
            },
        },
        {
            title: 'Status',
            dataIndex: 'status',
            key: 'status',
            sorter: true,
        }
    ];

    const landingPage = () => <Table dataSource={rows} columns={columns} />;

    const proposal = (id) => {
        console.log(id);
        const proposal = arcs[id].content;
        setBody(<Card>
            <h1>ARC-{id}: {arcs[id].metadata.title}</h1>
            <br/>
            <Readme readme={proposal}/>
        </Card>)
    }

    const [body, setBody] = useState(landingPage());

    return (
        <Layout className="layout">
            <Header className="header">
                <a onClick={() => setBody(landingPage())}><div className="logo"/></a>
                {/*<Menu theme="dark" mode="horizontal" defaultSelectedKeys={['1']}>*/}
                {/*    <Menu.Item key="1"></Menu.Item>*/}
                {/*</Menu>*/}
            </Header>
            <Content style={{ padding: '50px 50px' }}>
                {body}
            </Content>
            <Footer style={{ textAlign: 'center' }}>Visit the <a href="https://github.com/AleoHQ/ARCs">ARCs Github repository</a>.</Footer>
        </Layout>
    );
}

export default App;
